//
//  SensorDataProcessor.swift
//  OralableApp
//
//  Created: November 19, 2025
//  FIXED: November 28, 2025 - Removed * 1000 multiplication causing Int16 overflow
//  FIXED: December 5, 2025 - Added EMG support for ANR M40 device (treat .emg like .ppgInfrared)
//  FIXED: December 8, 2025 - Per-device battery tracking to fix dual-device battery export
//  FIXED: December 10, 2025 - Timestamp grouping bug fix (use Int64 ms instead of Date as key)
//  Responsibility: Process and aggregate raw sensor readings from BLE devices
//  - PPG data processing (Red, IR, Green channels)
//  - EMG data processing (ANR M40 - treated as ppgInfrared equivalent)
//  - Accelerometer data aggregation
//  - Temperature processing
//  - Battery level processing (per-device)
//  - Circular buffer management for each sensor type
//

import Foundation
import Combine

/// Processes raw sensor readings and manages circular buffers for historical data
@MainActor
class SensorDataProcessor: ObservableObject {

    // MARK: - Shared Instance
    static let shared = SensorDataProcessor()

    // MARK: - Published History Buffers

    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 100)
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 100)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 100)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 100)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 5000)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 100)
    @Published var sensorDataHistory: [SensorData] = []
    @Published var logMessages: [LogMessage] = []
    
    // MARK: - Current Sensor Values

    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var batteryLevel: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0

    // MARK: - Per-Device Battery Levels
    
    /// Battery level from Oralable hardware (0-100%)
    @Published var batteryLevelOralable: Double = 0.0
    
    /// Battery level from ANR M40 (-1 = N/A, ANR doesn't report battery)
    @Published var batteryLevelANR: Double = -1.0

    // MARK: - PPG Buffer for Heart Rate Calculation
    
    var ppgIRBuffer: [UInt32] = []

    // MARK: - Initialization

    init() {
        Logger.shared.info("[SensorDataProcessor] Initialized with circular buffers")
    }

    // MARK: - Battery Level Helpers

    /// Update battery level for a specific device
    /// - Parameters:
    ///   - value: Battery percentage (0-100)
    ///   - deviceType: The device type (.oralable or .anr)
    func updateBatteryLevel(_ value: Double, for deviceType: DeviceType) {
        switch deviceType {
        case .oralable:
            batteryLevelOralable = value
            batteryLevel = value
            Logger.shared.debug("[SensorDataProcessor] 🔋 Oralable battery: \(Int(value))%")
        case .anr:
            batteryLevelANR = value
            Logger.shared.debug("[SensorDataProcessor] 🔋 ANR M40 battery: N/A")
        case .demo:
            batteryLevel = value
            Logger.shared.debug("[SensorDataProcessor] 🔋 Demo battery: \(Int(value))%")
        }
    }
    
    /// Get cached battery level for Oralable device (for CSV export)
    func getCachedOralableBattery() -> Int {
        return Int(batteryLevelOralable)
    }

    /// Get battery level for a specific device type
    /// - Parameter deviceType: The device type to get battery level for
    /// - Returns: Battery percentage (0-100), or -1 for ANR (no battery reporting)
    func getBatteryLevel(for deviceType: DeviceType) -> Double {
        switch deviceType {
        case .oralable:
            return batteryLevelOralable
        case .anr:
            return batteryLevelANR
        case .demo:
            return batteryLevel
        }
    }

    // MARK: - Main Processing Method

    /// Process a batch of sensor readings from BLE devices
    /// - Parameter readings: Array of SensorReading objects from OralableDevice or ANRMuscleSenseDevice
    func processSensorReadings(_ readings: [SensorReading]) async {
        guard !readings.isEmpty else { return }

        // Categorize readings for efficient processing
        var batteryUpdates: [(BatteryData, Int)] = []
        var hrUpdates: [HeartRateData] = []
        var spo2Updates: [SpO2Data] = []
        var tempUpdates: [(Double, TemperatureData)] = []
        var hasPPGData = false
        var hasAccelData = false

        // Check if this batch is from Oralable (has PPG Red/Green) or ANR M40 (EMG only)
        let isFromOralable = readings.contains { $0.sensorType == .ppgRed || $0.sensorType == .ppgGreen }
        
        // Update per-device battery levels
        // NOTE: Battery readings ONLY come from Oralable hardware
        // ANR M40 does NOT have a battery characteristic
        if let batteryReading = readings.first(where: { $0.sensorType == .battery }) {
            await MainActor.run {
                let batteryValue = batteryReading.value
                
                // Battery ALWAYS comes from Oralable (ANR M40 doesn't report battery)
                // Even if the batch contains EMG data, the battery is from Oralable
                self.batteryLevelOralable = batteryValue
                Logger.shared.debug("[SensorDataProcessor] 🔋 Oralable battery from batch: \(Int(batteryValue))%")
                
                // Also update legacy fallback
                self.batteryLevel = batteryValue
            }
        }

        // FIX: Group readings by hardware frame number for deterministic grouping
        // PPG/accelerometer readings have frameNumber set by OralableDevice
        // Other readings (battery, temp) fall back to timestamp-based grouping
        var groupedReadings: [Int64: [SensorReading]] = [:]
        for reading in readings {
            let groupKey: Int64
            if let frameNum = reading.frameNumber {
                // PPG/accelerometer readings: group by hardware frame number
                groupKey = Int64(frameNum)
            } else {
                // Non-framed readings (battery, temp, heart rate): use 25ms timestamp buckets
                let milliseconds = Int64(reading.timestamp.timeIntervalSince1970 * 1000)
                groupKey = (milliseconds / 25) * 25
            }
            groupedReadings[groupKey, default: []].append(reading)
        }

        // Build the new SensorData objects off the main actor
        let sortedKeys = groupedReadings.keys.sorted()
        var newSensorData: [SensorData] = []
        newSensorData.reserveCapacity(sortedKeys.count)

        for groupKey in sortedKeys {
            guard let group = groupedReadings[groupKey] else { continue }
            // Use timestamp from first reading in group
            let timestamp = group.first?.timestamp ?? Date()
            let sensorData = self.convertToSensorData(readings: group, timestamp: timestamp)
            newSensorData.append(sensorData)
        }

        // Publish/append to sensorDataHistory in one go on the main actor
        await MainActor.run {
            let beforeCount = self.sensorDataHistory.count
            if !newSensorData.isEmpty {
                // Append all new items once
                self.sensorDataHistory.append(contentsOf: newSensorData)

                // Trim to cap (keep last 10000 for ~40 seconds of history at 250Hz)
                if self.sensorDataHistory.count > 10000 {
                    self.sensorDataHistory.removeFirst(self.sensorDataHistory.count - 10000)
                }

                let addedCount = newSensorData.count
                Logger.shared.debug("[SensorDataProcessor] ✅ Processed \(addedCount) entries, buffer: \(self.sensorDataHistory.count)/10000")

                if let oldest = self.sensorDataHistory.first?.timestamp,
                   let newest = self.sensorDataHistory.last?.timestamp {
                    Logger.shared.debug("[SensorDataProcessor] 📅 Data range: \(oldest) to \(newest)")
                }
            }
        }

        // Process individual reading types for legacy buffers
        for reading in readings {
            switch reading.sensorType {
            case .battery:
                let value = Int(reading.value)
                let data = BatteryData(percentage: value, timestamp: reading.timestamp)
                batteryUpdates.append((data, value))
                // Log which device the battery came from
                Logger.shared.debug("[SensorDataProcessor] Battery from Oralable cache: \(value)%")

            case .heartRate:
                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                hrUpdates.append(hrData)

            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2Updates.append(spo2Data)

            case .temperature:
                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                tempUpdates.append((reading.value, tempData))

            case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
                // EMG from ANR M40 is treated identically to ppgInfrared for muscle activity
                hasPPGData = true

            case .accelerometerX, .accelerometerY, .accelerometerZ:
                hasAccelData = true

            default:
                break
            }
        }

        // Apply all updates on main thread
        await MainActor.run {
            // Battery updates
            for (data, value) in batteryUpdates {
                self.batteryLevel = Double(value)
                self.batteryHistory.append(data)
                if value % 10 == 0 {
                    Logger.shared.debug("[SensorDataProcessor] Battery: \(value)%")
                }
            }

            // Heart rate updates
            for hrData in hrUpdates {
                self.heartRateHistory.append(hrData)
                if hrData.quality < 0.5 || hrData.bpm < 40 || hrData.bpm > 200 {
                    Logger.shared.warning("[SensorDataProcessor] Heart Rate: \(Int(hrData.bpm)) bpm | Quality: \(String(format: "%.2f", hrData.quality))")
                }
            }

            // SpO2 updates
            for spo2Data in spo2Updates {
                self.spo2History.append(spo2Data)
                if spo2Data.percentage < 90 {
                    Logger.shared.warning("[SensorDataProcessor] SpO2: \(Int(spo2Data.percentage))% | Quality: \(String(format: "%.2f", spo2Data.quality))")
                }
            }

            // Temperature updates
            for (value, data) in tempUpdates {
                self.temperature = value
                self.temperatureHistory.append(data)
            }
        }

        // Process PPG and accel data (if present)
        if hasPPGData {
            await updatePPGHistory(from: readings)
        }
        if hasAccelData {
            await updateAccelHistory(from: readings)
        }
    }

    /// Update PPG history and extract IR samples for heart rate calculation
    @discardableResult
    func updatePPGHistory(from readings: [SensorReading]) async -> [UInt32] {
        // FIX: Group by hardware frame number for deterministic grouping
        var grouped: [Int64: (red: Int32, ir: Int32, green: Int32, timestamp: Date)] = [:]
        var irSamples: [UInt32] = []

        for reading in readings where [.ppgRed, .ppgInfrared, .ppgGreen, .emg].contains(reading.sensorType) {
            let groupKey: Int64
            if let frameNum = reading.frameNumber {
                groupKey = Int64(frameNum)
            } else {
                let milliseconds = Int64(reading.timestamp.timeIntervalSince1970 * 1000)
                groupKey = (milliseconds / 25) * 25
            }
            var current = grouped[groupKey] ?? (0, 0, 0, reading.timestamp)

            switch reading.sensorType {
            case .ppgRed:
                current.red = Int32(reading.value)
                await MainActor.run { self.ppgRedValue = reading.value }
            case .ppgInfrared, .emg:
                // EMG from ANR M40 is stored in IR channel (equivalent signal type)
                current.ir = Int32(reading.value)
                await MainActor.run { self.ppgIRValue = reading.value }
                if reading.value > 0 {
                    irSamples.append(UInt32(reading.value))
                }
            case .ppgGreen:
                current.green = Int32(reading.value)
                await MainActor.run { self.ppgGreenValue = reading.value }
            default:
                break
            }

            grouped[groupKey] = current
        }

        // Update PPG history on main thread
        await MainActor.run {
            let sortedKeys = grouped.keys.sorted()
            for groupKey in sortedKeys {
                guard let values = grouped[groupKey] else { continue }
                let ppgData = PPGData(red: values.red, ir: values.ir, green: values.green, timestamp: values.timestamp)
                self.ppgHistory.append(ppgData)

                // Collect IR samples for HR calculation
                if values.ir > 0 {
                    self.ppgIRBuffer.append(UInt32(values.ir))
                }
            }
        }

        return irSamples
    }

    /// Get current PPG IR buffer for heart rate calculation
    func getPPGIRBuffer() -> [UInt32] {
        return ppgIRBuffer
    }

    /// Clear PPG IR buffer after heart rate calculation
    func clearPPGIRBuffer() {
        ppgIRBuffer.removeAll(keepingCapacity: true)
    }

    /// Append a single IR sample to the buffer (for real-time HR calculation)
    func appendToPPGIRBuffer(_ value: UInt32) {
        ppgIRBuffer.append(value)
    }

    /// Trim PPG IR buffer to keep only the last N samples (sliding window)
    func trimPPGIRBuffer(keepLast count: Int) {
        guard ppgIRBuffer.count > count else { return }
        let removeCount = ppgIRBuffer.count - count
        ppgIRBuffer.removeFirst(removeCount)
        Logger.shared.debug("[SensorDataProcessor] Trimmed PPG IR buffer to \(ppgIRBuffer.count) samples")
    }

    /// Update accelerometer history
    func updateAccelHistory(from readings: [SensorReading]) async {
        // FIX: Group by hardware frame number for deterministic grouping
        var grouped: [Int64: (x: Int16, y: Int16, z: Int16, timestamp: Date)] = [:]

        for reading in readings where [.accelerometerX, .accelerometerY, .accelerometerZ].contains(reading.sensorType) {
            let groupKey: Int64
            if let frameNum = reading.frameNumber {
                groupKey = Int64(frameNum)
            } else {
                let milliseconds = Int64(reading.timestamp.timeIntervalSince1970 * 1000)
                groupKey = (milliseconds / 25) * 25
            }
            var current = grouped[groupKey] ?? (0, 0, 0, reading.timestamp)

            // Values come as raw Int16 from OralableDevice (already correct units)
            let rawValue = Int16(clamping: Int(reading.value))

            switch reading.sensorType {
            case .accelerometerX:
                current.x = rawValue
                await MainActor.run { self.accelX = reading.value }
            case .accelerometerY:
                current.y = rawValue
                await MainActor.run { self.accelY = reading.value }
            case .accelerometerZ:
                current.z = rawValue
                await MainActor.run { self.accelZ = reading.value }
            default:
                break
            }

            grouped[groupKey] = current
        }

        // Update accelerometer history on main thread
        await MainActor.run {
            let sortedKeys = grouped.keys.sorted()
            for groupKey in sortedKeys {
                guard let values = grouped[groupKey] else { continue }
                let accelData = AccelerometerData(x: values.x, y: values.y, z: values.z, timestamp: values.timestamp)
                self.accelerometerHistory.append(accelData)
            }
        }
    }

    /// Clear all history buffers
    func clearHistory() {
        let priorCount = sensorDataHistory.count
        batteryHistory.removeAll()
        heartRateHistory.removeAll()
        spo2History.removeAll()
        temperatureHistory.removeAll()
        accelerometerHistory.removeAll()
        ppgHistory.removeAll()
        sensorDataHistory.removeAll()
        ppgIRBuffer.removeAll()
        logMessages.removeAll()
        
        // Also clear per-device battery levels
        batteryLevelOralable = 0.0
        batteryLevelANR = -1.0  // ANR doesn't report battery, keep as N/A
        batteryLevel = 0.0
        
        Logger.shared.info("[SensorDataProcessor] ✅ Cleared all history data | Removed \(priorCount) sensor data entries | New count: \(sensorDataHistory.count)")
    }

    // MARK: - Accelerometer G-Unit Conversions

    /// Get latest accelerometer values in g units
    var accelerometerInG: (x: Double, y: Double, z: Double, magnitude: Double)? {
        guard let latest = accelerometerHistory.last else { return nil }

        let xG = AccelerometerConversion.toG(latest.x)
        let yG = AccelerometerConversion.toG(latest.y)
        let zG = AccelerometerConversion.toG(latest.z)
        let mag = AccelerometerConversion.magnitude(xG: xG, yG: yG, zG: zG)

        return (x: xG, y: yG, z: zG, magnitude: mag)
    }

    /// Get current accelerometer values as raw Int16 tuple
    var accelerometerRaw: (x: Int16, y: Int16, z: Int16)? {
        guard let latest = accelerometerHistory.last else { return nil }
        return (x: latest.x, y: latest.y, z: latest.z)
    }

    /// Check if device is approximately at rest based on accelerometer magnitude
    var isAtRest: Bool {
        guard let latest = accelerometerHistory.last else { return false }
        return AccelerometerConversion.isAtRest(x: latest.x, y: latest.y, z: latest.z)
    }

    /// Get accelerometer history converted to g units (last N samples)
    func accelerometerHistoryInG(limit: Int = 100) -> [(timestamp: Date, x: Double, y: Double, z: Double, magnitude: Double)] {
        let samples = accelerometerHistory.suffix(limit)
        return samples.map { sample in
            let xG = AccelerometerConversion.toG(sample.x)
            let yG = AccelerometerConversion.toG(sample.y)
            let zG = AccelerometerConversion.toG(sample.z)
            let mag = AccelerometerConversion.magnitude(xG: xG, yG: yG, zG: zG)
            return (timestamp: sample.timestamp, x: xG, y: yG, z: zG, magnitude: mag)
        }
    }

    // MARK: - Private Helper Methods

    private func convertToSensorData(readings: [SensorReading], timestamp: Date) -> SensorData {
        var ppgRed: Int32 = 0, ppgIR: Int32 = 0, ppgGreen: Int32 = 0
        var accelX: Int16 = 0, accelY: Int16 = 0, accelZ: Int16 = 0
        var temperature: Double = 36.0
        var batteryFromReading: Int? = nil  // Track if we got a battery reading
        var heartRate: Double? = nil, heartRateQuality: Double? = nil
        var spo2: Double? = nil, spo2Quality: Double? = nil
        var detectedDeviceType: DeviceType = .oralable

        for reading in readings {
            switch reading.sensorType {
            case .ppgRed:
                ppgRed = Int32(reading.value)
            case .ppgInfrared:
                ppgIR = Int32(reading.value)
            case .ppgGreen:
                ppgGreen = Int32(reading.value)
            case .emg:
                // EMG from ANR M40 is stored in IR channel
                ppgIR = Int32(reading.value)
                detectedDeviceType = .anr
            case .accelerometerX:
                accelX = Int16(clamping: Int(reading.value))
            case .accelerometerY:
                accelY = Int16(clamping: Int(reading.value))
            case .accelerometerZ:
                accelZ = Int16(clamping: Int(reading.value))
            case .temperature:
                temperature = reading.value
            case .battery:
                batteryFromReading = Int(reading.value)
            case .heartRate:
                heartRate = reading.value
                heartRateQuality = reading.quality
            case .spo2:
                spo2 = reading.value
                spo2Quality = reading.quality
            default:
                break
            }
        }

        // Use battery from reading if available, otherwise use cached Oralable battery
        let batteryValue = batteryFromReading ?? Int(batteryLevelOralable)

        let ppgData = PPGData(red: ppgRed, ir: ppgIR, green: ppgGreen, timestamp: timestamp)
        let accelData = AccelerometerData(x: accelX, y: accelY, z: accelZ, timestamp: timestamp)
        let tempData = TemperatureData(celsius: temperature, timestamp: timestamp)
        let batteryData = BatteryData(percentage: batteryValue, timestamp: timestamp)
        let heartRateData = heartRate.map { HeartRateData(bpm: $0, quality: heartRateQuality ?? 0.8, timestamp: timestamp) }
        let spo2Data = spo2.map { SpO2Data(percentage: $0, quality: spo2Quality ?? 0.8, timestamp: timestamp) }

        return SensorData(
            timestamp: timestamp,
            ppg: ppgData,
            accelerometer: accelData,
            temperature: tempData,
            battery: batteryData,
            heartRate: heartRateData,
            spo2: spo2Data,
            deviceType: detectedDeviceType
        )
    }
    
    func updateLegacySensorData(with readings: [SensorReading]) async {
        let hasEMG = readings.contains { $0.sensorType == .emg || $0.sensorType == .muscleActivity }
        let hasPPG = readings.contains { $0.sensorType == .ppgRed || $0.sensorType == .ppgGreen }

        if let batteryReading = readings.first(where: { $0.sensorType == .battery }) {
            let batteryValue = batteryReading.value
            batteryLevelOralable = batteryValue
            Logger.shared.debug("[SensorDataProcessor] Battery from Oralable cache: \(Int(batteryValue))%")
            batteryLevel = batteryValue
        }

        // FIX: Group readings by hardware frame number for deterministic grouping
        // PPG/accelerometer readings have frameNumber set by OralableDevice
        // Other readings (battery, temp) fall back to timestamp-based grouping
        var groupedReadings: [Int64: [SensorReading]] = [:]
        for reading in readings {
            let groupKey: Int64
            if let frameNum = reading.frameNumber {
                // PPG/accelerometer readings: group by hardware frame number
                groupKey = Int64(frameNum)
            } else {
                // Non-framed readings (battery, temp, heart rate): use 25ms timestamp buckets
                let milliseconds = Int64(reading.timestamp.timeIntervalSince1970 * 1000)
                groupKey = (milliseconds / 25) * 25
            }
            groupedReadings[groupKey, default: []].append(reading)
        }

        let sortedKeys = groupedReadings.keys.sorted()
        var newSensorData: [SensorData] = []
        newSensorData.reserveCapacity(sortedKeys.count)

        for groupKey in sortedKeys {
            guard let group = groupedReadings[groupKey] else { continue }
            // Use timestamp from first reading in group
            let timestamp = group.first?.timestamp ?? Date()
            let sensorData = self.convertToSensorData(readings: group, timestamp: timestamp)
            newSensorData.append(sensorData)
        }

        if !newSensorData.isEmpty {
            self.sensorDataHistory.append(contentsOf: newSensorData)
            if self.sensorDataHistory.count > 10000 {
                self.sensorDataHistory.removeFirst(self.sensorDataHistory.count - 10000)
            }
            Logger.shared.debug("[SensorDataProcessor] ✅ Processed \(newSensorData.count) entries, buffer: \(self.sensorDataHistory.count)/10000")
            if let oldest = self.sensorDataHistory.first?.timestamp,
               let newest = self.sensorDataHistory.last?.timestamp {
                Logger.shared.debug("[SensorDataProcessor] 📅 Data range: \(oldest) to \(newest)")
            }
        }
    }

    // MARK: - Log Management

    func addLog(_ message: String) {
        logMessages.append(LogMessage(message: message))
    }
}
