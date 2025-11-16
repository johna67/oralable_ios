# Phase 2 Refactoring Plan

**Status:** In Progress
**Branch:** `claude/evaluate-oralable-app-01YE6hQDSyMYKf5MnKC43HpP`
**Started:** November 16, 2025

## Overview

Phase 2 builds on Phase 1's foundation to address deeper architectural issues and performance bottlenecks.

## Phase 1 Recap (Completed ✅)

- ✅ BaseViewModel class for code reuse
- ✅ AppConfiguration for centralized settings
- ✅ SwiftLint for code quality
- ✅ Auto-reconnect for BLE resilience

## Phase 2 Goals

### 1. Unify BLE Management (Priority: HIGH) 🔥

**Problem:**
Currently, the app has TWO parallel BLE management systems:
- `OralableBLE.swift` (~500 lines) - Legacy compatibility wrapper
- `DeviceManager.swift` (~620 lines) - Modern multi-device manager

**Current Usage Analysis:**
```
OralableBLE.shared used in:
- ✗ DashboardViewModel
- ✗ DevicesViewModel
- ✗ SettingsViewModel
- ✗ DashboardView
- ✗ DevicesView
- ✗ SettingsView
- ✗ ShareView
- ✗ ViewerModeView
- ✗ HistoricalDataManager
- ✗ OralableApp (root)

DeviceManager.shared used in:
- ✓ ShareViewModel
- ✓ DashboardView (partial - passes to DevicesView)
- ✓ OralableApp (root)
```

**Migration Strategy:**

**Step 1: Extend DeviceManager** (Make it feature-complete)
Add missing features from OralableBLE to DeviceManager:
- [x] Multi-device support (already has)
- [ ] Single device convenience properties (isConnected, deviceName, batteryLevel)
- [ ] Published sensor values (heartRate, spO2, temperature, ppgRedValue, etc.)
- [ ] Recording session management (startRecording, stopRecording)
- [ ] PPG channel order configuration
- [ ] Scanning state (already has)

**Step 2: Create Bridge Layer** (Temporary compatibility)
Add extension to DeviceManager that mimics OralableBLE interface:
```swift
extension DeviceManager {
    // Primary device convenience accessors
    var isConnected: Bool { !connectedDevices.isEmpty }
    var deviceName: String { primaryDevice?.name ?? "No Device" }
    var batteryLevel: Double { /* from primary device */ }

    // Published sensor values from primary device
    @Published var heartRate: Int
    @Published var spO2: Int
    // ... etc
}
```

**Step 3: Migrate ViewModels** (One at a time)
Order of migration (least to most complex):
1. DevicesViewModel (simplest - already close)
2. SettingsViewModel (medium - uses PPG config)
3. DashboardViewModel (complex - uses many sensors)

**Step 4: Migrate Views**
Update Views to use DeviceManager-injected ViewModels

**Step 5: Deprecate OralableBLE**
- Mark as @available(*, deprecated)
- Remove from OralableApp root
- Delete file in Phase 3

**Estimated Effort:** 6-8 hours
**Risk Level:** Medium (requires careful testing)

---

### 2. Implement Data Throttling (Priority: HIGH) 🔥

**Problem:**
From git history:
```
525f90f - Remove ALL per-packet logging to fix UI freeze
7965ce9 - Fix log throttling
```
High-frequency sensor data (50-100Hz) causes UI freezes when processing every packet.

**Solution: Actor-Based Data Throttler**

Create generic throttler for any data stream:

```swift
actor DataThrottler<T> {
    private var lastEmissionTime: Date?
    private let minimumInterval: TimeInterval
    private var pendingValue: T?

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    func throttle(_ value: T) async -> T? {
        let now = Date()

        // Store pending value
        pendingValue = value

        // Check if enough time has passed
        if let last = lastEmissionTime,
           now.timeIntervalSince(last) < minimumInterval {
            return nil // Too soon, drop this value
        }

        // Emit the pending value
        lastEmissionTime = now
        let valueToEmit = pendingValue
        pendingValue = nil
        return valueToEmit
    }

    // Get latest pending value without throttling check
    func latestValue() async -> T? {
        pendingValue
    }
}
```

**Usage in DeviceManager:**
```swift
private let sensorThrottler = DataThrottler<SensorReading>(
    minimumInterval: AppConfiguration.UI.sensorDataThrottleInterval // 0.1s
)

private func handleSensorReading(_ reading: SensorReading, from device: BLEDeviceProtocol) {
    Task {
        if let throttled = await sensorThrottler.throttle(reading) {
            // Only emit every 100ms instead of every packet
            await MainActor.run {
                allSensorReadings.append(throttled)
                latestReadings[throttled.sensorType] = throttled
            }
        }
    }
}
```

**Benefits:**
- Prevents UI freezes from high-frequency data
- Reduces memory pressure
- Actor-based = thread-safe
- Generic = reusable for any data type
- Configurable via AppConfiguration

**Estimated Effort:** 2-3 hours
**Risk Level:** Low (isolated change)

---

### 3. Expand Test Coverage (Priority: MEDIUM) 📊

**Current State:**
- 7 unit test files
- ~8.5% estimated coverage
- No integration tests

**Target:**
- 40% coverage (Phase 2)
- 60% coverage (Phase 3)

**New Tests to Add:**

**A. BaseViewModel Tests**
```swift
// BaseViewModelTests.swift
class BaseViewModelTests: XCTestCase {
    func testErrorHandling() { }
    func testLoadingState() { }
    func testWithLoadingSuccess() { }
    func testWithLoadingFailure() { }
    func testClearMessages() { }
}
```

**B. DeviceManager Tests**
```swift
// DeviceManagerTests.swift
class DeviceManagerTests: XCTestCase {
    func testDeviceDiscovery() { }
    func testDeviceConnection() { }
    func testAutoReconnect() { }
    func testReconnectBackoff() { }
    func testCancelReconnect() { }
    func testMaxReconnectAttempts() { }
}
```

**C. DataThrottler Tests**
```swift
// DataThrottlerTests.swift
class DataThrottlerTests: XCTestCase {
    func testThrottlesFrequentUpdates() async { }
    func testEmitsAfterInterval() async { }
    func testStoresLatestValue() async { }
}
```

**D. AppConfiguration Tests**
```swift
// AppConfigurationTests.swift
class AppConfigurationTests: XCTestCase {
    func testBLEConfigValues() { }
    func testSensorThresholds() { }
    func testFeatureFlags() { }
}
```

**Testing Tools:**
- XCTest (built-in)
- Mock objects for BLE peripherals
- Async/await testing

**Estimated Effort:** 8-10 hours
**Risk Level:** Low (only affects tests)

---

## Implementation Order

### Week 1: BLE Unification
- [ ] Day 1-2: Extend DeviceManager with missing features
- [ ] Day 3: Create compatibility bridge
- [ ] Day 4: Migrate DevicesViewModel
- [ ] Day 5: Migrate SettingsViewModel

### Week 2: BLE Completion + Throttling
- [ ] Day 1-2: Migrate DashboardViewModel
- [ ] Day 3: Update all Views
- [ ] Day 4: Implement DataThrottler
- [ ] Day 5: Integration testing

### Week 3: Testing
- [ ] Day 1-2: Write BaseViewModel tests
- [ ] Day 3: Write DeviceManager tests
- [ ] Day 4: Write DataThrottler tests
- [ ] Day 5: Run full test suite, fix issues

---

## Success Criteria

**BLE Unification:**
- ✓ All ViewModels use DeviceManager only
- ✓ All Views use DeviceManager only
- ✓ OralableBLE marked as deprecated
- ✓ No compilation warnings
- ✓ App connects and streams data correctly

**Data Throttling:**
- ✓ DataThrottler actor implemented
- ✓ Integrated in DeviceManager
- ✓ No UI freezes during high-frequency data
- ✓ Configurable via AppConfiguration

**Test Coverage:**
- ✓ 20+ new unit tests added
- ✓ Coverage increased from 8.5% to 40%+
- ✓ All tests passing
- ✓ CI/CD pipeline updated (if exists)

---

## Rollback Plan

If issues arise:
1. Revert to Phase 1 branch: `git revert <commit-range>`
2. Keep AppConfiguration and BaseViewModel (stable)
3. Fix issues before re-attempting migration
4. Use feature flags to enable/disable new code

---

## Phase 3 Preview (Next)

After Phase 2 completion:
- Delete OralableBLE.swift entirely
- Implement persistent storage (Core Data)
- Add ML-based anomaly detection
- Expand to 60% test coverage
- Profile and optimize performance

---

**Document Status:** Living document, updated as Phase 2 progresses
**Last Updated:** November 16, 2025
**Next Review:** After BLE unification completion
