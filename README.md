# Oralable iOS

<p align="center">
  <img src="https://img.shields.io/badge/iOS-15.0+-blue.svg" alt="iOS 15.0+"/>
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9"/>
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" alt="SwiftUI 3.0"/>
  <img src="https://img.shields.io/badge/Architecture-MVVM-purple.svg" alt="MVVM"/>
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License"/>
</p>

## Overview

**Oralable** is a comprehensive iOS health monitoring application designed to connect to specialized Bluetooth Low Energy (BLE) devices for real-time physiological data collection and analysis. The app focuses on PPG (Photoplethysmography) signal monitoring, bruxism detection, and comprehensive health metrics tracking.

### Key Features

- 🩺 **Real-Time Health Monitoring**
  - PPG signal analysis (Red, IR, Green wavelengths)
  - Heart rate calculation and tracking
  - SpO2 (blood oxygen saturation) measurement
  - Body temperature monitoring
  - 3-axis accelerometer data for movement detection

- 📱 **Modern iOS App**
  - Built entirely with SwiftUI
  - MVVM architecture for clean separation of concerns
  - Native iOS 15+ features
  - Dark mode support
  - Responsive design for iPhone and iPad

- 📊 **Data Management**
  - Historical data tracking and visualization
  - CSV data import/export
  - Apple HealthKit integration
  - iCloud/CloudKit synchronization
  - Configurable data retention periods

- 🔒 **Privacy & Security**
  - Local-first data storage
  - Apple Sign-In authentication
  - Optional cloud backup
  - HIPAA-conscious data handling

- 💳 **Subscription System**
  - StoreKit 2 integration
  - Multiple subscription tiers
  - Restore purchases functionality
  - Free tier with basic features

## Table of Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Installation](#installation)
- [Architecture](#architecture)
- [Features](#features)
- [Configuration](#configuration)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/johna67/oralable_ios.git
   cd oralable_ios
   ```

2. **Open in Xcode**
   ```bash
   open OralableApp/OralableApp.xcodeproj
   ```

3. **Configure App Identifiers**
   - Update Bundle Identifier in project settings
   - Configure StoreKit products (see [StoreKit Configuration](#storekit-configuration))
   - Set up iCloud container identifier

4. **Build and Run**
   - Select a simulator or device
   - Press `Cmd+R` to build and run

## Requirements

### System Requirements
- **Xcode**: 15.0 or later
- **macOS**: 13.0 (Ventura) or later
- **iOS Deployment Target**: 15.0+

### Dependencies
- No third-party dependencies! 🎉
- Uses only native Apple frameworks:
  - SwiftUI
  - Combine
  - CoreBluetooth
  - HealthKit
  - StoreKit 2
  - CloudKit
  - AuthenticationServices

### Hardware
- Physical iOS device for BLE testing (simulator can't access Bluetooth)
- Compatible BLE device (Oralable or ANR Muscle Sense)

## Installation

### For Development

1. **Clone and Configure**
   ```bash
   git clone https://github.com/johna67/oralable_ios.git
   cd oralable_ios/OralableApp
   ```

2. **Configure Signing**
   - Open `OralableApp.xcodeproj` in Xcode
   - Go to Signing & Capabilities
   - Select your development team
   - Update bundle identifier if needed

3. **Configure Capabilities**
   - ✅ HealthKit
   - ✅ Sign in with Apple
   - ✅ iCloud (CloudKit)
   - ✅ Push Notifications
   - ✅ Background Modes (Bluetooth)

4. **Build**
   ```bash
   xcodebuild -project OralableApp.xcodeproj -scheme OralableApp -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

### For Testing

See [SETUP.md](docs/SETUP.md) for detailed testing setup instructions.

## Architecture

Oralable follows the **MVVM (Model-View-ViewModel)** pattern with a clean separation of concerns:

```
┌─────────────────────────────────────────────┐
│                  Views                      │
│  (SwiftUI - UI Layer)                      │
└────────────────┬────────────────────────────┘
                 │
                 │ @StateObject / @ObservedObject
                 ▼
┌─────────────────────────────────────────────┐
│              ViewModels                      │
│  (Business Logic & State Management)        │
└────────────────┬────────────────────────────┘
                 │
                 │ Uses
                 ▼
┌─────────────────────────────────────────────┐
│               Managers                       │
│  (Services: BLE, HealthKit, Data, etc.)    │
└────────────────┬────────────────────────────┘
                 │
                 │ Operates on
                 ▼
┌─────────────────────────────────────────────┐
│                Models                        │
│  (Data Structures & Business Entities)     │
└─────────────────────────────────────────────┘
```

### Key Components

- **Views**: SwiftUI views with minimal logic
- **ViewModels**: Observable objects managing view state
- **Managers**: Singleton services (BLE, HealthKit, Subscriptions)
- **Models**: Data structures and protocols
- **Components**: Reusable UI components

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## Features

### 1. Dashboard View
Real-time health monitoring with live charts:
- Connection status
- Current heart rate and SpO2
- PPG waveform visualization
- Accelerometer data
- Battery and temperature monitoring

### 2. Historical Data View
Comprehensive historical analysis:
- Time range selection (day/week/month)
- Interactive charts with multiple metrics
- Summary statistics
- Trend analysis
- Data export functionality

### 3. Device Management
BLE device connection and configuration:
- Device scanning and pairing
- PPG channel order configuration
- Device firmware information
- Connection status monitoring
- Multi-device support

### 4. Settings
Comprehensive app configuration:
- Device settings (auto-connect, channel order)
- Notification preferences
- Display settings (units, time format)
- Data management (retention, clear data)
- Privacy controls
- Subscription management

### 5. Data Export/Import
Flexible data management:
- CSV export with configurable date ranges
- Selective data type export
- Import previously exported data
- Multiple export formats (CSV, JSON, PDF planned)

## Configuration

### StoreKit Configuration

1. **Create Products in App Store Connect**
   - Monthly subscription: `com.oralable.mam.subscription.monthly`
   - Yearly subscription: `com.oralable.mam.subscription.yearly`
   - Lifetime purchase: `com.oralable.mam.lifetime`

2. **Update Product IDs** (if needed)
   Edit `SubscriptionManager.swift`:
   ```swift
   private enum ProductIdentifier {
       static let monthlySubscription = "your.product.id.monthly"
       static let yearlySubscription = "your.product.id.yearly"
       static let lifetimePurchase = "your.product.id.lifetime"
   }
   ```

3. **Test with StoreKit Configuration File**
   - Create `Products.storekit` in Xcode
   - Add test products matching your IDs
   - Run app in simulator for testing

See [docs/STOREKIT_SETUP.md](docs/STOREKIT_SETUP.md) for detailed instructions.

### HealthKit Configuration

Required capabilities in `Info.plist`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to read your health data for comprehensive analysis.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need access to write health data to your Health app.</string>
```

### iCloud Configuration

1. Enable iCloud capability
2. Configure CloudKit container: `iCloud.jacdentalsolutions.OralableApp`
3. Update container identifier if needed

## Testing

### Running Tests

```bash
# Run all tests
xcodebuild test -project OralableApp.xcodeproj -scheme OralableApp -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test file
xcodebuild test -project OralableApp.xcodeproj -scheme OralableApp -only-testing:OralableAppTests/DashboardViewModelTests
```

### Test Coverage

- ✅ **ViewModel Tests**: DashboardViewModel, DevicesViewModel, HistoricalViewModel, SettingsViewModel
- ✅ **Manager Tests**: SubscriptionManager
- 🔄 **Integration Tests**: (Planned)
- 🔄 **UI Tests**: (Planned)

### Continuous Integration

GitHub Actions workflow runs on every push:
```yaml
.github/workflows/ios.yml
```

## Project Structure

```
OralableApp/
├── OralableApp/
│   ├── Assets.xcassets/       # App icons, colors, images
│   ├── Components/            # Reusable UI components
│   │   ├── Avatar/
│   │   ├── Buttons/
│   │   ├── Rows/
│   │   └── Sections/
│   ├── Devices/              # BLE device implementations
│   │   ├── OralableDevice.swift
│   │   └── ANRMuscleSenseDevice.swift
│   ├── Managers/             # Business logic services
│   │   ├── BLECentralManager.swift
│   │   ├── DeviceManager.swift
│   │   ├── HealthKitManager.swift
│   │   ├── HistoricalDataManager.swift
│   │   ├── SubscriptionManager.swift
│   │   └── DesignSystem/
│   ├── Models/               # Data models
│   │   ├── Devices/
│   │   ├── Sensors/
│   │   ├── HealthData.swift
│   │   └── HistoricalDataModels.swift
│   ├── Protocols/            # Protocol definitions
│   │   └── BLEDeviceProtocol.swift
│   ├── ViewModels/           # MVVM view models
│   │   ├── DashboardViewModel.swift
│   │   ├── DevicesViewModel.swift
│   │   ├── HistoricalViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/                # SwiftUI views
│   │   ├── DashboardView.swift
│   │   ├── DevicesView.swift
│   │   ├── HistoricalView.swift
│   │   ├── SettingsView.swift
│   │   └── MainTabView.swift
│   ├── Info.plist
│   ├── OralableApp.entitlements
│   └── OralableApp.swift     # App entry point
├── OralableAppTests/         # Unit tests
└── OralableAppUITests/       # UI tests
```

## BLE Protocol

### Nordic UART Service
- **Service UUID**: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **TX Characteristic** (Write): `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX Characteristic** (Notify): `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

### Data Packet Structure
- **Packet Size**: 244 bytes
- **Samples per Packet**: 20
- **Bytes per Sample**: 12
- **Data Format**: See [PPG_DEBUGGING_GUIDE.md](OralableApp/OralableApp/PPG_DEBUGGING_GUIDE.md)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write tests for new features
- Update documentation

## Versioning

We use [Semantic Versioning](https://semver.org/):
- **Major**: Breaking changes
- **Minor**: New features (backwards compatible)
- **Patch**: Bug fixes

Current version: **1.0.0** (Build 2025.11.07)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Apple frameworks team for excellent native tools
- Nordic Semiconductor for BLE UART service specification
- Open source community for inspiration

## Support

- **Issues**: [GitHub Issues](https://github.com/johna67/oralable_ios/issues)
- **Discussions**: [GitHub Discussions](https://github.com/johna67/oralable_ios/discussions)
- **Email**: support@oralable.com

## Roadmap

- [ ] Advanced analytics dashboard
- [ ] Machine learning bruxism detection
- [ ] Multi-language support
- [ ] Apple Watch companion app
- [ ] Widget support
- [ ] Siri shortcuts integration
- [ ] PDF export functionality

---

**Built with ❤️ using Swift and SwiftUI**
