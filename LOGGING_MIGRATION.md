# Logging Migration Guide

## Overview

The Oralable iOS app now uses a structured logging framework instead of scattered `print()` statements. This provides better debugging capabilities, log management, and performance in production builds.

## Why Migrate?

### Problems with `print()`:
- ❌ No log levels (everything is the same priority)
- ❌ No filtering or searching
- ❌ Console spam in production builds
- ❌ No persistent logging
- ❌ No source tracking
- ❌ Performance overhead in release builds
- ❌ Cannot disable debug logs in production

### Benefits of Structured Logging:
- ✅ Log levels (debug, info, warning, error)
- ✅ Automatic source tracking (file, function, line)
- ✅ Timestamps on all logs
- ✅ Filtering by level or time range
- ✅ File logging in debug builds
- ✅ Export logs to CSV
- ✅ Debug logs stripped in release builds
- ✅ SwiftUI integration with LogsView
- ✅ Performance optimized

## Quick Start

### Before (Old Way):
```swift
print("🔐 Apple ID Sign In:")
print("  User ID: \(userID)")
print("⚠️ Low battery: \(batteryLevel)%")
print("❌ Failed to connect: \(error)")
```

### After (New Way):
```swift
logInfo("Apple ID Sign In")
logInfo("User ID: \(userID)")
logWarning("Low battery: \(batteryLevel)%")
logError("Failed to connect: \(error)")
```

## Logging Levels

| Level | Purpose | Release Build | Example Usage |
|-------|---------|---------------|---------------|
| **debug** | Detailed debugging info | ❌ Stripped | `logDebug("Buffer size: \(buffer.count)")` |
| **info** | General information | ✅ Included | `logInfo("Connected to device")` |
| **warning** | Warnings, non-critical | ✅ Included | `logWarning("Low battery: 15%")` |
| **error** | Errors and failures | ✅ Included | `logError("Connection failed")` |

## Usage Examples

### Basic Logging
```swift
// Debug information (stripped in release)
logDebug("Starting scan for devices")

// General information
logInfo("Connected to Oralable-001")

// Warnings
logWarning("Signal quality low: \(quality)")

// Errors
logError("Failed to parse data: \(error)")
```

### Using the Singleton
```swift
// Direct access to Logger singleton
await Logger.shared.info("User authenticated")
await Logger.shared.warning("Cache miss for key: \(key)")
```

### Accessing Advanced Features
```swift
// Get logs by level
let errorLogs = await Logger.shared.service.logs(withLevel: .error)

// Get logs by time range
let recentLogs = await Logger.shared.service.logs(
    from: Date().addingTimeInterval(-3600),
    to: Date()
)

// Export logs to file
let exportURL = try await Logger.shared.service.exportLogs()

// Clear all logs
await Logger.shared.service.clearLogs()
```

## Migration Strategy

### Phase 1: Critical Components (Priority)
Replace `print()` in:
- [ ] `BLECentralManager.swift` (37 prints)
- [ ] `DeviceManager.swift` (147 prints)
- [ ] `AuthenticationManager.swift` (29 prints)
- [ ] `OralableBLE.swift` (7 prints)

### Phase 2: Supporting Components
- [ ] `HeartRateCalculator.swift` (4 prints)
- [ ] `HealthKitManager.swift`
- [ ] `SubscriptionManager.swift`
- [ ] ViewModels

### Phase 3: Views and UI
- [ ] `DevicesView.swift` (12 prints)
- [ ] `LogsView.swift`
- [ ] Other views

## Emoji to Log Level Mapping

When migrating, convert emoji prefixes to appropriate log levels:

| Emoji | Old Pattern | New Level | Example |
|-------|-------------|-----------|---------|
| 🔍 | Discovery/Search | `debug` | `logDebug("Scanning...")` |
| ✅ | Success | `info` | `logInfo("Connected successfully")` |
| 📱 📦 📊 | Info/Data | `info` | `logInfo("Received data")` |
| ⚠️ | Warning | `warning` | `logWarning("Low battery")` |
| ❌ 🚫 | Error/Failure | `error` | `logError("Connection failed")` |
| 🔐 💾 | Security/Storage | `info` | `logInfo("Data saved")` |
| 🔋 🔌 | Hardware Status | `info` | `logInfo("Battery: 85%")` |

## Performance Considerations

### Debug Builds:
- All log levels included
- File logging enabled
- Full source tracking
- ~0.1ms per log call

### Release Builds:
- `debug` logs completely stripped (zero overhead)
- File logging disabled
- Console output for info/warning/error only
- ~0.05ms per log call

### Best Practices:
```swift
// ✅ Good: Use debug for verbose logging
logDebug("Processing \(samples.count) samples")

// ❌ Bad: Don't use info for verbose data
// logInfo("Sample values: \(samples)")

// ✅ Good: Log important state changes
logInfo("Connected to device: \(deviceName)")

// ✅ Good: Log warnings for recoverable issues
logWarning("Retrying connection (attempt \(attempt)/3)")

// ✅ Good: Log errors with context
logError("Failed to parse PPG data: \(error.localizedDescription)")

// ❌ Bad: Don't log in tight loops
// for sample in samples {
//     logDebug("Processing \(sample)") // Will spam logs
// }

// ✅ Good: Log summary instead
logDebug("Processed \(samples.count) samples successfully")
```

## Integration with SwiftUI

The logging service is available via environment:

```swift
struct MyView: View {
    @Environment(\.logger) var logger

    var body: some View {
        Button("Test") {
            logger.info("Button tapped")
        }
    }
}
```

## LogsView Integration

The app includes a `LogsView` for viewing logs in-app:

```swift
// Navigate to logs view
NavigationLink("View Logs") {
    LogsView()
}
```

Features:
- Filter by log level
- Search logs
- Export to CSV
- Real-time log updates
- Color-coded by severity

## Conditional Compilation

Debug logs are automatically stripped in release builds:

```swift
// This code is COMPLETELY REMOVED in release builds
logDebug("Detailed sensor data: \(data)")

// Only the check is removed, logging still happens
logInfo("User logged in")  // Stays in release
```

## Testing

### Mock Logger for Tests:
```swift
let mockLogger = MockLoggingService()
mockLogger.info("Test message")

// Assert logs
XCTAssertEqual(mockLogger.recentLogs.count, 1)
XCTAssertEqual(mockLogger.recentLogs.first?.level, .info)
```

## FAQ

**Q: Should I remove all `print()` statements?**
A: Yes, gradually migrate all `print()` to appropriate log levels. Use `logDebug()` for development-only messages.

**Q: What about performance-critical code?**
A: Use `logDebug()` which is completely stripped in release builds. For production logs, use `logInfo()` sparingly.

**Q: Can I still see logs in Xcode console?**
A: Yes! All logs still print to console with formatted timestamps and source information.

**Q: How do I view logs on device?**
A: Use the in-app LogsView or export logs to CSV via Settings.

**Q: What happens to old logs?**
A: In-memory logs are limited to 1000 entries (configurable). File logs rotate at 10MB.

## Example: Migrating a File

### Before (`BLECentralManager.swift`):
```swift
func startScanning(services: [CBUUID]? = nil) {
    print("[BLECentralManager] Starting scan...")
    guard central.state == .poweredOn else {
        print("❌ Cannot scan - Bluetooth off")
        return
    }
    central.scanForPeripherals(withServices: services)
    print("✅ Scan started")
}
```

### After:
```swift
func startScanning(services: [CBUUID]? = nil) {
    logDebug("Starting scan for services: \(services?.map { $0.uuidString } ?? [])")

    guard central.state == .poweredOn else {
        logError("Cannot scan - Bluetooth not powered on (state: \(central.state.rawValue))")
        return
    }

    central.scanForPeripherals(withServices: services)
    logInfo("Scan started successfully")
}
```

## Summary

| Feature | print() | Logger |
|---------|---------|--------|
| Log Levels | ❌ | ✅ 4 levels |
| Source Tracking | ❌ | ✅ Auto |
| Timestamps | ❌ | ✅ Auto |
| Filtering | ❌ | ✅ Yes |
| Export | ❌ | ✅ CSV |
| File Logging | ❌ | ✅ Debug only |
| Performance | ⚠️ Always on | ✅ Optimized |
| Release Builds | ⚠️ Overhead | ✅ Minimal |
| SwiftUI Integration | ❌ | ✅ Environment |

---

**Next Steps:**
1. Start using `logDebug()`, `logInfo()`, `logWarning()`, `logError()` in new code
2. Gradually migrate existing `print()` statements
3. Remove emoji prefixes (handled by log levels)
4. Test in both debug and release configurations
5. Use LogsView to verify logging works as expected

For questions or issues, see `Managers/Logger.swift` and `Models/Devices/LoggingService.swift`.
