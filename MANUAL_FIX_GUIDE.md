# Manual Fix Guide - Critical Production Issues

Apply these fixes to `claude/refactor-code-011CV5arPTknJHYnVzXGewCZ` branch

## Quick Stats
- 3 files to modify
- 25+ print() statements to remove
- 4 named constants to add
- **Estimated time: 5-10 minutes**

---

## File 1: OralableDevice.swift

### Location: Line ~227 in `parseData()` function

**REMOVE these 3 lines:**
```swift
print("\n📦 [OralableDevice] parseData called")
print("📦 [OralableDevice] Characteristic: \(characteristic.uuid.uuidString)")
print("📦 [OralableDevice] Data length: \(data.count) bytes")
```

**REMOVE these lines from the switch cases (lines ~233-255):**
```swift
print("📦 [OralableDevice] Parsing PPG sensor data")
print("📦 [OralableDevice] Parsing accelerometer waveform data")
print("📦 [OralableDevice] Parsing battery level data")
print("📦 [OralableDevice] Detected 4-byte packet, parsing as battery voltage")
print("📦 [OralableDevice] Detected 8-byte packet, parsing as temperature")
print("📦 [OralableDevice] Detected 244-byte packet, parsing as PPG data")
print("📦 [OralableDevice] Detected 154-156 byte packet, parsing as accelerometer data")
```

**CHANGE line ~247:**
```swift
// FROM:
print("⚠️ [OralableDevice] Unknown characteristic UUID and unrecognized data length: \(data.count) bytes")

// TO:
Logger.shared.warning("[OralableDevice] Unknown characteristic UUID and unrecognized data length: \(data.count) bytes")
```

### Location: Line ~323 in `parseSensorData()`

**CHANGE:**
```swift
// FROM:
print("⚠️ [OralableDevice] Insufficient data for PPG parsing: \(data.count) bytes")

// TO:
Logger.shared.warning("[OralableDevice] Insufficient data for PPG parsing: \(data.count) bytes")
```

**REMOVE line ~333:**
```swift
print("📦 [OralableDevice] PPG Frame #\(frameCounter)")
```

**REMOVE lines ~353-360 (these 8 lines):**
```swift
// Create sensor readings for each sample
// Note: We send individual readings but also log summary stats
// Use Int64 to prevent overflow when summing Int32 values
let avgRed = Double(redSamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(redSamples.count)
let avgIR = Double(irSamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(irSamples.count)
let avgGreen = Double(greenSamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(greenSamples.count)

print("📊 [OralableDevice] PPG Averages - Red: \(Int(avgRed)), IR: \(Int(avgIR)), Green: \(Int(avgGreen))")
```

**REMOVE line ~407:**
```swift
print("✅ [OralableDevice] Parsed \(readings.count) PPG sensor readings (20 samples × 3 channels)")
```

### Location: Line ~420 in `parsePPGWaveform()`

**CHANGE:**
```swift
// FROM:
print("⚠️ [OralableDevice] Insufficient data for accelerometer parsing: \(data.count) bytes")

// TO:
Logger.shared.warning("[OralableDevice] Insufficient data for accelerometer parsing: \(data.count) bytes")
```

**REMOVE line ~431:**
```swift
print("📦 [OralableDevice] Accelerometer Frame #\(frameCounter)")
```

**REMOVE lines ~456-462 (these 7 lines):**
```swift
// Log summary statistics
// Use Int64 to prevent overflow when summing Int16 values
let avgX = Double(xSamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(xSamples.count) * scaleFactor
let avgY = Double(ySamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(ySamples.count) * scaleFactor
let avgZ = Double(zSamples.reduce(Int64(0), { $0 + Int64($1) })) / Double(zSamples.count) * scaleFactor

print("📊 [OralableDevice] Accel Averages - X: \(String(format: "%.3f", avgX))g, Y: \(String(format: "%.3f", avgY))g, Z: \(String(format: "%.3f", avgZ))g")
```

**REMOVE line ~509:**
```swift
print("✅ [OralableDevice] Parsed \(readings.count) accelerometer readings (25 samples × 3 axes)")
```

### Location: Line ~518 in `parseBatteryData()`

**CHANGE:**
```swift
// FROM:
print("⚠️ [OralableDevice] Insufficient data for battery parsing: \(data.count) bytes")

// TO:
Logger.shared.warning("[OralableDevice] Insufficient data for battery parsing: \(data.count) bytes")
```

**CHANGE line ~541:**
```swift
// FROM:
print("🔋 [OralableDevice] Battery: \(String(format: "%.2f", voltageInVolts))V (\(Int(percentage))%)")

// TO:
Logger.shared.debug("[OralableDevice] Battery: \(String(format: "%.2f", voltageInVolts))V (\(Int(percentage))%)")
```

### Location: Line ~552 in `parseTemperatureData()`

**CHANGE:**
```swift
// FROM:
print("⚠️ [OralableDevice] Insufficient data for temperature parsing: \(data.count) bytes")

// TO:
Logger.shared.warning("[OralableDevice] Insufficient data for temperature parsing: \(data.count) bytes")
```

**CHANGE line ~571:**
```swift
// FROM:
print("🌡️ [OralableDevice] Temperature Frame #\(frameCounter): \(String(format: "%.2f", temperatureCelsius))°C")

// TO:
Logger.shared.debug("[OralableDevice] Temperature: \(String(format: "%.2f", temperatureCelsius))°C")
```

---

## File 2: OralableBLE.swift

### Location: Line ~86, after `private let maxHistoryCount = 100`

**ADD these lines:**
```swift
    // PPG Processing Constants
    private let maxPPGBufferSize = 300      // 6 seconds at 50Hz sampling rate
    private let minHeartRateSamples = 20    // 0.4 seconds required for HR calculation
    private let minSpO2Samples = 150        // 3 seconds required for accurate SpO2 calculation
    private let maxMetricHistoryCount = 1000 // Maximum history items for HR and SpO2
```

### Location: Line ~220 in `updateHistoriesFromReadings()`

**REMOVE these 2 lines:**
```swift
print("📥 [OralableBLE] updateHistoriesFromReadings called with \(readings.count) total readings")
print("📥 [OralableBLE] Processing \(recentReadings.count) recent readings")
```

**REMOVE these lines from within the switch statement:**
```swift
print("🔋 [OralableBLE] Updated batteryLevel: \(reading.value)")
print("🌡️ [OralableBLE] Updated temperature: \(reading.value)")
print("🔴 [OralableBLE] Updated ppgRedValue: \(reading.value)")
print("📐 [OralableBLE] Updated accelX: \(reading.value)")
```

### Location: Line ~397 in `processPPGData()`

**CHANGE:**
```swift
// FROM:
let maxBufferSize = 300
if ppgBufferRed.count > maxBufferSize {
    ppgBufferRed.removeFirst(ppgBufferRed.count - maxBufferSize)
    ppgBufferIR.removeFirst(ppgBufferIR.count - maxBufferSize)
    ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxBufferSize)
}

// TO:
if ppgBufferRed.count > maxPPGBufferSize {
    ppgBufferRed.removeFirst(ppgBufferRed.count - maxPPGBufferSize)
    ppgBufferIR.removeFirst(ppgBufferIR.count - maxPPGBufferSize)
    ppgBufferGreen.removeFirst(ppgBufferGreen.count - maxPPGBufferSize)
}
```

**CHANGE line ~405:**
```swift
// FROM:
if ppgBufferIR.count >= 20 {

// TO:
if ppgBufferIR.count >= minHeartRateSamples {
```

**CHANGE lines ~416-417:**
```swift
// FROM:
if heartRateHistory.count > 1000 {
    heartRateHistory.removeFirst(heartRateHistory.count - 1000)

// TO:
if heartRateHistory.count > maxMetricHistoryCount {
    heartRateHistory.removeFirst(heartRateHistory.count - maxMetricHistoryCount)
```

**CHANGE line ~425:**
```swift
// FROM:
if ppgBufferRed.count >= 150, ppgBufferIR.count >= 150 {

// TO:
if ppgBufferRed.count >= minSpO2Samples, ppgBufferIR.count >= minSpO2Samples {
```

**CHANGE lines ~438-439:**
```swift
// FROM:
if spo2History.count > 1000 {
    spo2History.removeFirst(spo2History.count - 1000)

// TO:
if spo2History.count > maxMetricHistoryCount {
    spo2History.removeFirst(spo2History.count - maxMetricHistoryCount)
```

**CHANGE line ~448:**
```swift
// FROM:
Logger.shared.debug("[OralableBLE] ⏳ SpO2: Accumulating data (\(ppgBufferRed.count)/150 samples)")

// TO:
Logger.shared.debug("[OralableBLE] ⏳ SpO2: Accumulating data (\(ppgBufferRed.count)/\(minSpO2Samples) samples)")
```

---

## File 3: DashboardViewModel.swift

### Location: Line ~92 in `setupBLESubscriptions()`

**REMOVE these 7 lines:**
```swift
print("📊 [DashboardViewModel] Setting up BLE subscriptions...")
print("📊 [DashboardViewModel] Received ppgRedValue: \(value)")
print("📊 [DashboardViewModel] Received accel: X=\(x), Y=\(y), Z=\(z)")
print("📊 [DashboardViewModel] Received temperature: \(temp)")
print("📊 [DashboardViewModel] BLE subscriptions set up complete")
```

---

## After Making Changes

1. **Build in Xcode** to verify no compilation errors
2. **Commit the changes:**
   ```bash
   git add -A
   git commit -m "Fix critical production issues

   - Remove 25+ debug print() statements
   - Extract magic numbers to named constants
   - Replace print() with Logger.shared calls
   - Improves performance and maintainability"
   ```
3. **Push to remote:**
   ```bash
   git push origin claude/refactor-code-011CV5arPTknJHYnVzXGewCZ
   ```

## Summary
- ✅ Removed 25+ print() statements
- ✅ Added 4 named constants
- ✅ Replaced print() with Logger calls
- ✅ No functional changes, only code quality improvements

