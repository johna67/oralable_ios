# Oralable iOS - Architecture Documentation

## Table of Contents

- [Overview](#overview)
- [Architecture Pattern](#architecture-pattern)
- [Project Structure](#project-structure)
- [Data Flow](#data-flow)
- [Core Components](#core-components)
- [Design Patterns](#design-patterns)
- [State Management](#state-management)
- [Dependencies](#dependencies)

## Overview

Oralable iOS follows a modern, scalable architecture built on **MVVM (Model-View-ViewModel)** pattern with protocol-oriented design principles. The app is built entirely with native Apple frameworks, featuring no third-party dependencies.

### Key Architectural Principles

1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data layers
2. **Protocol-Oriented Design**: Flexible, testable interfaces
3. **Reactive Programming**: Combine framework for data flow and state management
4. **Dependency Injection**: Testable, loosely coupled components
5. **Single Responsibility**: Each component has one clear purpose

## Architecture Pattern

### MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────────────────┐
│                        View Layer                            │
│                      (SwiftUI Views)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ DashboardView│  │ DevicesView  │  │SettingsView  │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                   │                 │              │
│         │ @StateObject      │                 │              │
│         │                   │                 │              │
└─────────┼───────────────────┼─────────────────┼──────────────┘
          │                   │                 │
          ▼                   ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                           │
│                 (Business Logic & State)                     │
│  ┌──────────────────┐  ┌──────────────┐  ┌───────────────┐│
│  │DashboardViewModel│  │DevicesViewModel│ │SettingsVM     ││
│  │                  │  │                │  │               ││
│  │ @Published       │  │ @Published     │  │ @Published    ││
│  │ - isConnected    │  │ - devices      │  │ - settings    ││
│  │ - heartRate      │  │ - isScanning   │  │ - ppgOrder    ││
│  │ - spo2           │  │ - selected     │  │               ││
│  └────────┬─────────┘  └───────┬────────┘  └──────┬────────┘│
│           │                    │                   │         │
└───────────┼────────────────────┼───────────────────┼─────────┘
            │                    │                   │
            │ Uses               │                   │
            ▼                    ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                     Manager Layer                            │
│                  (Services & Coordinators)                   │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │DeviceManager│  │HealthKitMgr  │  │SubscriptionMgr   │  │
│  │BLECentral   │  │HistoricalMgr │  │AuthManager       │  │
│  └──────┬──────┘  └──────┬───────┘  └───────┬──────────┘  │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          │ Operates on    │                    │
          ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                      Model Layer                             │
│                  (Data & Business Entities)                  │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │SensorData   │  │HealthData    │  │SubscriptionTier  │  │
│  │DeviceInfo   │  │PPGData       │  │UserSettings      │  │
│  │PPGChannelOrder│ │AccelData    │  │                  │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

### Directory Organization

```
OralableApp/
├── Components/           # Reusable UI components
│   ├── Avatar/          # User avatar components
│   ├── Buttons/         # Custom button styles
│   ├── Rows/            # List row components
│   └── Sections/        # Section headers & cards
│
├── Devices/             # BLE device implementations
│   ├── OralableDevice.swift
│   └── ANRMuscleSenseDevice.swift
│
├── Managers/            # Business logic services
│   ├── BLE/
│   │   ├── BLECentralManager.swift      # Core BLE operations
│   │   ├── DeviceManager.swift          # Device coordination
│   │   └── OralableBLE.swift           # Legacy compatibility
│   ├── Data/
│   │   ├── HistoricalDataManager.swift # Data aggregation
│   │   └── CSVExportManager.swift      # Data export
│   ├── Integration/
│   │   ├── HealthKitManager.swift      # Apple Health integration
│   │   └── AuthenticationManager.swift  # Apple Sign In
│   ├── Subscription/
│   │   └── SubscriptionManager.swift    # StoreKit integration
│   └── DesignSystem/
│       └── DesignSystem.swift           # Design tokens
│
├── Models/              # Data models & entities
│   ├── Devices/
│   │   ├── DeviceInfo.swift
│   │   └── DeviceType.swift
│   ├── Sensors/
│   │   ├── SensorModels.swift
│   │   ├── PPGData.swift
│   │   ├── AccelerometerData.swift
│   │   └── TemperatureData.swift
│   ├── HealthData.swift
│   └── HistoricalDataModels.swift
│
├── Protocols/           # Protocol definitions
│   └── BLEDeviceProtocol.swift
│
├── ViewModels/          # MVVM view models
│   ├── DashboardViewModel.swift
│   ├── DevicesViewModel.swift
│   ├── HistoricalViewModel.swift
│   ├── SettingsViewModel.swift
│   ├── AuthenticationViewModel.swift
│   └── ShareViewModel.swift
│
└── Views/               # SwiftUI views
    ├── Dashboard/
    ├── Devices/
    ├── Historical/
    ├── Settings/
    └── MainTabView.swift
```

## Data Flow

### 1. BLE Data Flow

```
┌──────────────┐
│ BLE Device   │
│ (Hardware)   │
└──────┬───────┘
       │ Bluetooth packets (244 bytes)
       ▼
┌─────────────────────┐
│ CBPeripheral        │
│ (CoreBluetooth)     │
└──────┬──────────────┘
       │ Raw data
       ▼
┌─────────────────────┐
│ BLECentralManager   │
│ - Scanning          │
│ - Connection        │
│ - Data reception    │
└──────┬──────────────┘
       │ Parsed data
       ▼
┌─────────────────────┐
│ DeviceManager       │
│ - Device coordination│
│ - Data parsing      │
└──────┬──────────────┘
       │ Structured data (SensorReading)
       ▼
┌─────────────────────┐
│ OralableBLE         │
│ (Compatibility)     │
│ @Published vars     │
└──────┬──────────────┘
       │ Published updates
       ▼
┌─────────────────────┐
│ ViewModel           │
│ - State management  │
│ - Business logic    │
└──────┬──────────────┘
       │ View state
       ▼
┌─────────────────────┐
│ SwiftUI View        │
│ - UI rendering      │
│ - User interaction  │
└─────────────────────┘
```

### 2. User Action Flow

```
User Tap → View → ViewModel → Manager → Model → Data Store
                                  ↓
                           Side Effects:
                           - BLE commands
                           - HealthKit updates
                           - Persistence
```

### 3. State Update Flow

```
Data Change → Manager → ViewModel (@Published) → View (automatic UI update)
```

## Core Components

### 1. Managers (Services)

#### BLECentralManager
**Purpose**: Low-level BLE communication
```swift
class BLECentralManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var isScanning: Bool = false

    func startScanning()
    func connect(to peripheral: CBPeripheral)
    func disconnect()
}
```

#### DeviceManager
**Purpose**: High-level device coordination
```swift
class DeviceManager: ObservableObject {
    @Published var connectedDevices: [any BLEDeviceProtocol] = []
    @Published var currentDevice: (any BLEDeviceProtocol)?

    func connectToDevice(_ peripheral: CBPeripheral, type: DeviceType)
    func processIncomingData(_ data: Data)
}
```

#### HealthKitManager
**Purpose**: Apple Health integration
```swift
class HealthKitManager: ObservableObject {
    func requestAuthorization()
    func saveHeartRate(_ bpm: Int)
    func saveSpO2(_ percentage: Int)
    func fetchHistoricalData(from: Date, to: Date)
}
```

#### SubscriptionManager
**Purpose**: In-app purchase management
```swift
@MainActor
class SubscriptionManager: ObservableObject {
    @Published var currentTier: SubscriptionTier
    @Published var availableProducts: [Product]

    func purchase(_ product: Product) async throws
    func restorePurchases() async throws
}
```

### 2. ViewModels

#### Common ViewModel Pattern
```swift
@MainActor
class ExampleViewModel: ObservableObject {
    // Published properties (observable by view)
    @Published var someState: String = ""

    // Private dependencies
    private let manager: SomeManager
    private var cancellables = Set<AnyCancellable>()

    // Initialization with dependency injection
    init(manager: SomeManager = .shared) {
        self.manager = manager
        setupBindings()
    }

    // Combine bindings
    private func setupBindings() {
        manager.$data
            .receive(on: DispatchQueue.main)
            .assign(to: &$someState)
    }

    // Public methods (called by view)
    func performAction() {
        // Business logic
    }
}
```

### 3. Views

#### View Structure
```swift
struct ExampleView: View {
    @StateObject private var viewModel = ExampleViewModel()
    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        // UI composition using computed properties
        contentView
    }

    // Computed properties for organization
    private var contentView: some View {
        VStack {
            // UI elements
        }
    }
}
```

## Design Patterns

### 1. Protocol-Oriented Design

**BLEDeviceProtocol**: Abstraction for different BLE devices
```swift
protocol BLEDeviceProtocol {
    var name: String { get }
    var peripheral: CBPeripheral { get }

    func processData(_ data: Data) -> SensorReading?
    func sendCommand(_ command: DeviceCommand)
}
```

**Benefits**:
- Multiple device types support
- Easy testing with mocks
- Clear contracts between layers

### 2. Singleton Pattern

Used for shared services:
- `SubscriptionManager.shared`
- `HealthKitManager.shared`
- `AuthenticationManager.shared`
- `DesignSystem.shared`

**Rationale**: These services maintain global state and should have single instances.

### 3. Dependency Injection

ViewModels accept dependencies through initializers:
```swift
// Production use
let viewModel = DashboardViewModel() // Uses .shared instances

// Testing use
let mockBLE = OralableBLE.mock()
let viewModel = DashboardViewModel(bleManager: mockBLE)
```

### 4. Observer Pattern

Implemented via Combine:
```swift
manager.$property
    .sink { newValue in
        // React to changes
    }
    .store(in: &cancellables)
```

### 5. Repository Pattern

**HistoricalDataManager** acts as a repository:
```swift
class HistoricalDataManager {
    func fetchData(from: Date, to: Date) -> [SensorReading]
    func saveReading(_ reading: SensorReading)
    func aggregate(by period: TimePeriod) -> [AggregatedData]
}
```

## State Management

### 1. Local State (@State)

For view-specific, temporary state:
```swift
@State private var isExpanded = false
@State private var selectedTab = 0
```

### 2. Observable State (@StateObject, @ObservedObject)

For ViewModel state:
```swift
@StateObject private var viewModel = DashboardViewModel()
```

### 3. Environment (@EnvironmentObject)

For globally shared state:
```swift
@EnvironmentObject var designSystem: DesignSystem
```

### 4. Published Properties

For reactive updates:
```swift
@Published var isConnected: Bool = false
```

## Dependencies

### Native Frameworks

1. **SwiftUI**: Modern declarative UI framework
2. **Combine**: Reactive programming and data flow
3. **CoreBluetooth**: BLE communication
4. **HealthKit**: Apple Health integration
5. **StoreKit**: In-app purchases
6. **CloudKit**: iCloud synchronization
7. **AuthenticationServices**: Apple Sign In

### Why No Third-Party Dependencies?

✅ **Advantages**:
- Reduced app size
- Better security
- No dependency management overhead
- Guaranteed iOS compatibility
- Faster build times

❌ **Trade-offs**:
- More code to write for some features
- Missing convenience of some popular libraries

## Performance Considerations

### 1. Memory Management

- **Weak references** in Combine subscriptions
- **Proper cleanup** in `deinit`
- **Lazy loading** of historical data

### 2. Threading

- **Main thread**: UI updates via `@MainActor`
- **Background threads**: BLE operations, data processing
- **Async/await**: Modern concurrency for async operations

### 3. Data Optimization

- **Pagination**: Historical data loaded in chunks
- **Caching**: Recent data kept in memory
- **Debouncing**: Search and filter operations

## Testing Strategy

### 1. Unit Tests

- **ViewModels**: Business logic testing
- **Managers**: Service testing with mocks
- **Models**: Data validation

### 2. Integration Tests

- **BLE flow**: Device connection to data display
- **HealthKit**: Data synchronization
- **Subscription**: Purchase flow

### 3. UI Tests

- **Navigation**: Tab switching, deep links
- **User flows**: Complete feature workflows

## Future Architecture Improvements

- [ ] **Modularization**: Split into feature modules
- [ ] **SwiftUI previews**: Better preview support
- [ ] **Dependency container**: Replace singletons
- [ ] **Router pattern**: Programmatic navigation
- [ ] **Use cases layer**: Extra business logic layer

---

**Last Updated**: November 11, 2025
