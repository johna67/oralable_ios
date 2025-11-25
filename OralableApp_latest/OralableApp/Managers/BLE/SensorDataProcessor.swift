//
//  SensorDataProcessor.swift
//  OralableApp
//
//  Created: November 19, 2025
//  Responsibility: Process and aggregate raw sensor readings from BLE devices
//  - PPG data processing (Red, IR, Green channels)
//  - Accelerometer data aggregation
//  - Temperature processing
//  - Battery level processing
//  - Circular buffer management for each sensor type
//

import Foundation
import Combine

/// Processes raw sensor readings and manages circular buffers for historical data
@MainActor
class SensorDataProcessor: ObservableObject {

    // MARK: - Published History Buffers

    @Published var batteryHistory: CircularBuffer<BatteryData> = CircularBuffer(capacity: 100)
    @Published var heartRateHistory: CircularBuffer<HeartRateData> = CircularBuffer(capacity: 100)
    @Published var spo2History: CircularBuffer<SpO2Data> = CircularBuffer(capacity: 100)
    @Published var temperatureHistory: CircularBuffer<TemperatureData> = CircularBuffer(capacity: 100)
    @Published var accelerometerHistory: CircularBuffer<AccelerometerData> = CircularBuffer(capacity: 100)
    @Published var ppgHistory: CircularBuffer<PPGData> = CircularBuffer(capacity: 100)
    @Published var sensorDataHistory: [SensorData] = []
    @Published var logMessages: [LogMessage] = []
    // MARK: - Current Sensor Values

    @Published var accelX: Double = 0.0
    @Published var accelY: Double = 0.0
    @Published var accelZ: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var ppgRedValue: Double = 0.0
    @Published var ppgIRValue: Double = 0.0
    @Published var ppgGreenValue: Double = 0.0
    @Published var batteryLevel: Double = 0.0

    // MARK: - Private Properties

    private let maxHistoryCount = 100
    private var ppgIRBuffer: [UInt32] = []  // Buffer for HR calculation

    #if DEBUG
    private var readingsCounter = 0  // Counter for debug logging
    #endif

    // MARK: - Initialization

    init() {
        Logger.shared.info("[SensorDataProcessor] Initialized")
    }

    // MARK: - Public Processing Methods

    /// Process a batch of sensor readings (called from background queue)
    func processBatch(_ readings: [SensorReading]) async {
        #if DEBUG
        readingsCounter += readings.count
        if readingsCounter >= 100 {
            let count = readingsCounter
            readingsCounter = 0
            Logger.shared.debug("[SensorDataProcessor] Processed \(count) readings in batch")
        }
        #endif

        // Track which types of data we have to avoid redundant processing
        var hasPPGData = false
        var hasAccelData = false

        // Prepare batched updates
        var batteryUpdates: [(BatteryData, Int)] = []
        var hrUpdates: [HeartRateData] = []
        var spo2Updates: [SpO2Data] = []
        var tempUpdates: [(Double, TemperatureData)] = []

        // Process each reading
        for reading in readings {
            switch reading.sensorType {
            case .battery:
                let batteryData = BatteryData(percentage: Int(reading.value), timestamp: reading.timestamp)
                batteryUpdates.append((batteryData, Int(reading.value)))

            case .heartRate:
                let hrData = HeartRateData(bpm: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                hrUpdates.append(hrData)

            case .spo2:
                let spo2Data = SpO2Data(percentage: reading.value, quality: reading.quality ?? 0.8, timestamp: reading.timestamp)
                spo2Updates.append(spo2Data)

            case .temperature:
                let tempData = TemperatureData(celsius: reading.value, timestamp: reading.timestamp)
                tempUpdates.append((reading.value, tempData))

            case .ppgRed, .ppgInfrared, .ppgGreen:
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
    func updatePPGHistory(from readings: [SensorReading]) async -> [UInt32] {
        var grouped: [Date: (red: Int32, ir: Int32, green: Int32)] = [:]
        var irSamples: [UInt32] = []

        for reading in readings where [.ppgRed, .ppgInfrared, .ppgGreen].contains(reading.sensorType) {
            // Use exact timestamp - DO NOT ROUND to preserve 20ms sample offsets
            let timestamp = reading.timestamp
            var current = grouped[timestamp] ?? (0, 0, 0)

            switch reading.sensorType {
            case .ppgRed:
                current.red = Int32(reading.value)
                await MainActor.run { self.ppgRedValue = reading.value }
            case .ppgInfrared:
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

            grouped[timestamp] = current
        }

        // Update PPG history on main thread
        await MainActor.run {
            for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
                let ppgData = PPGData(red: values.red, ir: values.ir, green: values.green, timestamp: timestamp)
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

    /// Update accelerometer history
    func updateAccelHistory(from readings: [SensorReading]) async {
        var grouped: [Date: (x: Int16, y: Int16, z: Int16)] = [:]

        for reading in readings where [.accelerometerX, .accelerometerY, .accelerometerZ].contains(reading.sensorType) {
            // Use exact timestamp - DO NOT ROUND to preserve 20ms sample offsets
            let timestamp = reading.timestamp
            var current = grouped[timestamp] ?? (0, 0, 0)

            switch reading.sensorType {
            case .accelerometerX:
                current.x = Int16(reading.value * 1000)
                await MainActor.run { self.accelX = reading.value }
            case .accelerometerY:
                current.y = Int16(reading.value * 1000)
                await MainActor.run { self.accelY = reading.value }
            case .accelerometerZ:
                current.z = Int16(reading.value * 1000)
                await MainActor.run { self.accelZ = reading.value }
            default:
                break
            }

            grouped[timestamp] = current
        }

        // Update accelerometer history on main thread
        await MainActor.run {
            for (timestamp, values) in grouped.sorted(by: { $0.key < $1.key }) {
                let accelData = AccelerometerData(x: values.x, y: values.y, z: values.z, timestamp: timestamp)
                self.accelerometerHistory.append(accelData)
            }
        }
    }

    /// Update legacy sensor data history (for backward compatibility)
    func updateLegacySensorData(with readings: [SensorReading]) async {
        // Group readings by exact timestamp (preserve offsets)
        var groupedReadings: [Date: [SensorReading]] = [:]
        for reading in readings {
            groupedReadings[reading.timestamp, default: []].append(reading)
        }

        // Build the new SensorData objects off the main actor
        let sortedTimestamps = groupedReadings.keys.sorted()
        var newSensorData: [SensorData] = []
        newSensorData.reserveCapacity(sortedTimestamps.count)

        for timestamp in sortedTimestamps {
            guard let group = groupedReadings[timestamp] else { continue }
            let sensorData = self.convertToSensorData(readings: group, timestamp: timestamp)
            newSensorData.append(sensorData)
        }

        // Publish/append to sensorDataHistory in one go on the main actor
        await MainActor.run {
            let beforeCount = self.sensorDataHistory.count
            if !newSensorData.isEmpty {
                // Append all new items once
                self.sensorDataHistory.append(contentsOf: newSensorData)

                // Trim to cap (keep last 1000)
                if self.sensorDataHistory.count > 1000 {
                    self.sensorDataHistory.removeFirst(self.sensorDataHistory.count - 1000)
                }

                let addedCount = self.sensorDataHistory.count - beforeCount
                Logger.shared.debug("[SensorDataProcessor] ✅ Bulk added \(addedCount) sensor data entries, total: \(self.sensorDataHistory.count)")

                if let oldest = self.sensorDataHistory.first?.timestamp,
                   let newest = self.sensorDataHistory.last?.timestamp {
                    Logger.shared.debug("[SensorDataProcessor] 📅 Data range: \(oldest) to \(newest)")
                }
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
        Logger.shared.info("[SensorDataProcessor] ✅ Cleared all history data | Removed \(priorCount) sensor data entries | New count: \(sensorDataHistory.count)")
    }

    // MARK: - Private Helper Methods

    private func convertToSensorData(readings: [SensorReading], timestamp: Date) -> SensorData {
        var ppgRed: Int32 = 0, ppgIR: Int32 = 0, ppgGreen: Int32 = 0
        var accelX: Int16 = 0, accelY: Int16 = 0, accelZ: Int16 = 0
        var temperature: Double = 36.0, battery: Int = 0
        var heartRate: Double? = nil, heartRateQuality: Double? = nil
        var spo2: Double? = nil, spo2Quality: Double? = nil

        for reading in readings {
            switch reading.sensorType {
            case .ppgRed: ppgRed = Int32(reading.value)
            case .ppgInfrared: ppgIR = Int32(reading.value)
            case .ppgGreen: ppgGreen = Int32(reading.value)
            case .accelerometerX: accelX = Int16(reading.value * 1000)
            case .accelerometerY: accelY = Int16(reading.value * 1000)
            case .accelerometerZ: accelZ = Int16(reading.value * 1000)
            case .temperature: temperature = reading.value
            case .battery: battery = Int(reading.value)
            case .heartRate: heartRate = reading.value; heartRateQuality = reading.quality ?? 0.8
            case .spo2: spo2 = reading.value; spo2Quality = reading.quality ?? 0.8
            default: break
            }
        }

        let ppgData = PPGData(red: ppgRed, ir: ppgIR, green: ppgGreen, timestamp: timestamp)
        let accelData = AccelerometerData(x: accelX, y: accelY, z: accelZ, timestamp: timestamp)
        let tempData = TemperatureData(celsius: temperature, timestamp: timestamp)
        let batteryData = BatteryData(percentage: battery, timestamp: timestamp)
        let heartRateData = heartRate.map { HeartRateData(bpm: $0, quality: heartRateQuality ?? 0.8, timestamp: timestamp) }
        let spo2Data = spo2.map { SpO2Data(percentage: $0, quality: spo2Quality ?? 0.8, timestamp: timestamp) }

        return SensorData(
            timestamp: timestamp,
            ppg: ppgData,
            accelerometer: accelData,
            temperature: tempData,
            battery: batteryData,
            heartRate: heartRateData,
            spo2: spo2Data
        )
        
        // MARK: - Log Management

        func addLog(_ message: String) {
            logMessages.append(LogMessage(message: message))
        }

        func clearHistory() {
            sensorDataHistory.removeAll()
            logMessages.removeAll()
            heartRateHistory = CircularBuffer(capacity: 100)
            spo2History = CircularBuffer(capacity: 100)
            temperatureHistory = CircularBuffer(capacity: 100)
            accelerometerHistory = CircularBuffer(capacity: 100)
            batteryHistory = CircularBuffer(capacity: 100)
            ppgHistory = CircularBuffer(capacity: 100)
            Logger.shared.info("[SensorDataProcessor] History cleared")
        }
    }
    
}
