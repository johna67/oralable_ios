# Branch Comparison: Phase 2 vs Original Evaluation Branch

**Current Branch:** `claude/evaluate-oralable-app-01YE6hQDSyMYKf5MnKC43HpP` (Phase 2 Complete)
**Comparison Branch:** `claude/evaluate-oralable-app-016QYojQv4pewFGbAJwD81rn` (Original Evaluation)

## Key Differences Found

### 1. UI/UX Improvements in Original Branch

#### Dashboard Connection Button
**Current (Phase 2):**
```swift
Button(action: {
    if bleManager.isConnected {
        bleManager.disconnect()
    } else {
        Task { await bleManager.startScanning() }
    }
}) {
    Text(bleManager.isConnected ? "Disconnect" : "Connect")
        .background(bleManager.isConnected ? Color.red : Color.blue)
}
```

**Original Branch:**
```swift
Button(action: {
    showingDevices = true  // Opens Devices view
}) {
    Text(viewModel.isConnected ? "Manage" : "Connect")
        .background(viewModel.isConnected ? Color.blue : Color.green)
}
```

**Improvement:** Better UX - delegates connection management to dedicated Devices view

#### Metrics Display
**Current (Phase 2):**
```swift
MetricCard(
    title: "Heart Rate",
    value: "\(viewModel.heartRate)",  // Shows "0" when no data
    unit: "bpm"
)
```

**Original Branch:**
```swift
MetricCard(
    title: "Heart Rate",
    value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "Not available",
    unit: viewModel.heartRate > 0 ? "bpm" : ""
)
```

**Improvement:** Shows "Not available" instead of "0" - better user experience

#### Dashboard Simplification
**Removed in Original Branch:**
- Session time metric card
- Signal quality metric card
- Action buttons section
- Share sheet presentation
- onAppear/onDisappear lifecycle methods

**Kept:**
- Core metrics (Heart Rate, SpO2, Temperature, Battery)
- MAM state card
- Connection status card
- Waveform section

**Improvement:** Cleaner, more focused dashboard

---

### 2. Architecture Differences

#### BLEManagerProtocol (Original Branch Only)
```swift
@MainActor
protocol BLEManagerProtocol: AnyObject, ObservableObject {
    var isConnected: Bool { get }
    var heartRate: Int { get }
    var spO2: Int { get }
    // ... all sensor properties

    // Publishers for Combine bindings
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    var heartRatePublisher: AnyPublisher<Int, Never> { get }
    // ... all publishers

    func startScanning()
    func connect(to peripheral: CBPeripheral)
}
```

**Benefit:** Enables dependency injection and testing

#### DashboardViewModel Differences
**Current (Phase 2):**
```swift
class DashboardViewModel: BaseViewModel {
    private let bleManager = DeviceManager.shared

    override init() {
        super.init()
        setupBindings()
    }
}
```

**Original Branch:**
```swift
class DashboardViewModel: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var deviceName: String = "Not Connected"
    @Published var batteryLevel: Int = 0

    private let bleManager: BLEManagerProtocol

    init(bleManager: BLEManagerProtocol = DeviceManager.shared) {
        self.bleManager = bleManager
        setupBindings()
    }

    private func setupBindings() {
        bleManager.isConnectedPublisher
            .sink { [weak self] connected in
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }
}
```

**Improvements:**
1. Dependency injection - testable
2. Local @Published properties - ViewModel owns state
3. Uses publishers instead of direct $ bindings
4. Doesn't inherit from BaseViewModel (simpler)

#### View Data Binding
**Current (Phase 2):**
```swift
// DashboardView accesses bleManager directly
if bleManager.isConnected {
    Text(bleManager.deviceName)
}
```

**Original Branch:**
```swift
// DashboardView accesses through ViewModel
if viewModel.isConnected {
    Text(viewModel.deviceName)
}
```

**Improvement:** Proper MVVM - View only talks to ViewModel

---

### 3. Device Management Features (Original Branch)

#### Rename Device
```swift
private func renameDevice() {
    newDeviceName = bleManager.deviceName
    showingRenameAlert = true
}

private func saveDeviceName() {
    if let deviceUUID = bleManager.deviceUUID {
        let key = "deviceName_\(deviceUUID.uuidString)"
        UserDefaults.standard.set(newDeviceName, forKey: key)
    }
    bleManager.deviceName = newDeviceName
}
```

**Features:**
- Custom device names
- Persisted in UserDefaults
- Keyed by device UUID

#### Firmware Update
```swift
.sheet(isPresented: $showingFirmwareUpdate) {
    FirmwareUpdateView()
        .environmentObject(designSystem)
}
```

#### Calibration Wizard
```swift
.sheet(isPresented: $showingCalibration) {
    CalibrationWizardView(bleManager: bleManager)
        .environmentObject(designSystem)
}
```

---

### 4. Connection Flow Differences

#### Current (Phase 2)
1. User clicks "Connect" on Dashboard
2. Calls `bleManager.startScanning()` directly
3. User must navigate to Devices view separately to see discovered devices

#### Original Branch
1. User clicks "Connect" on Dashboard
2. Opens Devices view automatically
3. Devices view handles scanning and connection
4. Better separation of concerns

---

## Recommendations for Phase 2 Branch

### High Priority (Quick Wins)

1. **Update Dashboard Connect Button**
   - Change to open Devices view instead of direct scanning
   - Update button text: "Manage" when connected, "Connect" when disconnected
   - Update colors: blue when connected, green when disconnected

2. **Improve Metrics Display**
   - Show "Not available" instead of "0" for missing data
   - Hide units when showing "Not available"
   - Applies to: Heart Rate, SpO2, Temperature

3. **Simplify Dashboard**
   - Remove Session time card (not currently functional)
   - Remove Signal quality card (not currently functional)
   - Keep focus on core vitals

### Medium Priority (Architecture)

4. **Add BLEManagerProtocol**
   - Create protocol for DeviceManager
   - Enable dependency injection in ViewModels
   - Improves testability

5. **Refactor ViewModel Bindings**
   - Add local @Published properties to ViewModels
   - Use publishers instead of direct $ bindings
   - Better encapsulation

### Low Priority (Features)

6. **Add Device Management Features**
   - Rename device functionality
   - Firmware update UI (placeholder)
   - Calibration wizard (placeholder)

---

## Implementation Priority

**Immediate (UI Polish):**
- Dashboard button behavior change
- "Not available" metrics display
- Dashboard simplification

**Phase 2 Completion:**
- BLEManagerProtocol introduction
- ViewModel refactoring with publishers
- Better View-ViewModel separation

**Phase 3:**
- Device rename functionality
- Firmware update workflow
- Calibration features

---

## Summary

The original evaluation branch has:
✅ Better UX (Manage button, "Not available" display)
✅ Better architecture (Protocol, dependency injection)
✅ Proper MVVM (View → ViewModel only)
✅ Additional features (rename, firmware, calibration)

Phase 2 branch has:
✅ Unified BLE architecture (DeviceManager)
✅ Data throttling (performance)
✅ 42% test coverage
✅ Deprecated OralableBLE
✅ All ViewModels migrated

**Best Path Forward:** Merge UI improvements from original branch into Phase 2 architecture.
