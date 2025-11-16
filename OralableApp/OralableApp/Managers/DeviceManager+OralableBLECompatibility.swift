//
//  DeviceManager+OralableBLECompatibility.swift
//  OralableApp
//
//  Created: Phase 2 Refactoring
//  Extension to provide OralableBLE-compatible interface for easier migration
//

import Foundation
import Combine
import CoreBluetooth

// MARK: - OralableBLE Compatibility Extension
//
// This extension adds convenience properties and methods to DeviceManager
// to match the OralableBLE interface, making ViewModel migration easier.
// These will eventually replace OralableBLE.swift entirely.

@MainActor
extension DeviceManager {

    // MARK: - Convenience Properties (Single-Device Access)

    /// Convenience: True if any device is connected
    var isConnected: Bool {
        !connectedDevices.isEmpty
    }

    /// Convenience: Name of primary device or "No Device"
    var deviceName: String {
        primaryDevice?.name ?? "No Device"
    }

    /// Convenience: UUID of primary device
    var deviceUUID: UUID? {
        primaryDevice?.id
    }

    /// Convenience: Connection state as string
    var connectionStatus: String {
        if isConnected {
            return "Connected"
        } else if isScanning {
            return "Scanning..."
        } else {
            return "Disconnected"
        }
    }

    /// Convenience: Connection state as descriptive string
    var connectionState: String {
        connectionStatus.lowercased()
    }

    // MARK: - Real-Time Sensor Values (from latestReadings)

    /// Latest battery level (0-100)
    var batteryLevel: Double {
        latestReadings[.battery]?.value ?? 0.0
    }

    /// Latest accelerometer X value (g)
    var accelX: Double {
        latestReadings[.accelerometerX]?.value ?? 0.0
    }

    /// Latest accelerometer Y value (g)
    var accelY: Double {
        latestReadings[.accelerometerY]?.value ?? 0.0
    }

    /// Latest accelerometer Z value (g)
    var accelZ: Double {
        latestReadings[.accelerometerZ]?.value ?? 1.0
    }

    /// Latest temperature in Celsius
    var temperature: Double {
        latestReadings[.temperature]?.value ?? 0.0
    }

    /// Latest PPG Red channel value
    var ppgRedValue: Double {
        latestReadings[.ppgRed]?.value ?? 0.0
    }

    /// Latest PPG Infrared channel value
    var ppgIRValue: Double {
        latestReadings[.ppgInfrared]?.value ?? 0.0
    }

    /// Latest PPG Green channel value
    var ppgGreenValue: Double {
        latestReadings[.ppgGreen]?.value ?? 0.0
    }

    /// Latest heart rate (bpm)
    var heartRate: Int {
        Int(latestReadings[.heartRate]?.value ?? 0)
    }

    /// Latest SpO2 percentage
    var spO2: Int {
        Int(latestReadings[.spo2]?.value ?? 0)
    }

    /// Latest heart rate quality (0.0-1.0)
    var heartRateQuality: Double {
        latestReadings[.heartRate]?.quality ?? 0.0
    }

    /// Latest RSSI signal strength
    var rssi: Int {
        latestReadings[.rssi]?.value.map { Int($0) } ?? -50
    }

    // MARK: - History Arrays (Derived from allSensorReadings)

    /// Battery level history
    var batteryHistory: [BatteryData] {
        allSensorReadings
            .filter { $0.sensorType == .battery }
            .map { BatteryData(percentage: Int($0.value), timestamp: $0.timestamp) }
    }

    /// Heart rate history
    var heartRateHistory: [HeartRateData] {
        allSensorReadings
            .filter { $0.sensorType == .heartRate }
            .map { HeartRateData(bpm: $0.value, quality: $0.quality ?? 0.8, timestamp: $0.timestamp) }
    }

    /// SpO2 history
    var spo2History: [SpO2Data] {
        allSensorReadings
            .filter { $0.sensorType == .spo2 }
            .map { SpO2Data(percentage: $0.value, quality: $0.quality ?? 0.8, timestamp: $0.timestamp) }
    }

    /// Temperature history
    var temperatureHistory: [TemperatureData] {
        allSensorReadings
            .filter { $0.sensorType == .temperature }
            .map { TemperatureData(celsius: $0.value, timestamp: $0.timestamp) }
    }

    /// Accelerometer history (grouped by timestamp)
    var accelerometerHistory: [AccelerometerData] {
        // Group accelerometer readings by rounded timestamp
        var grouped: [Date: (x: Int16, y: Int16, z: Int16)] = [:]

        for reading in allSensorReadings where [.accelerometerX, .accelerometerY, .accelerometerZ].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)

            switch reading.sensorType {
            case .accelerometerX: current.x = Int16(reading.value * 1000)
            case .accelerometerY: current.y = Int16(reading.value * 1000)
            case .accelerometerZ: current.z = Int16(reading.value * 1000)
            default: break
            }

            grouped[roundedTime] = current
        }

        return grouped
            .sorted { $0.key < $1.key }
            .map { AccelerometerData(x: $1.x, y: $1.y, z: $1.z, timestamp: $0) }
    }

    /// PPG history (grouped by timestamp)
    var ppgHistory: [PPGData] {
        // Group PPG readings by rounded timestamp
        var grouped: [Date: (red: Int32, ir: Int32, green: Int32)] = [:]

        for reading in allSensorReadings where [.ppgRed, .ppgInfrared, .ppgGreen].contains(reading.sensorType) {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            var current = grouped[roundedTime] ?? (0, 0, 0)

            switch reading.sensorType {
            case .ppgRed: current.red = Int32(reading.value)
            case .ppgInfrared: current.ir = Int32(reading.value)
            case .ppgGreen: current.green = Int32(reading.value)
            default: break
            }

            grouped[roundedTime] = current
        }

        return grouped
            .sorted { $0.key < $1.key }
            .map { PPGData(red: $1.red, ir: $1.ir, green: $1.green, timestamp: $0) }
    }

    /// Sensor data history (full combined data)
    var sensorDataHistory: [SensorData] {
        // Group all readings by rounded timestamp
        var grouped: [Date: [SensorReading]] = [:]

        for reading in allSensorReadings {
            let roundedTime = Date(timeIntervalSince1970: round(reading.timestamp.timeIntervalSince1970 * 10) / 10)
            grouped[roundedTime, default: []].append(reading)
        }

        return grouped
            .sorted { $0.key < $1.key }
            .map { convertToSensorData(readings: $1, timestamp: $0) }
    }

    // MARK: - Recording Session Management

    /// True if a recording session is active
    var isRecording: Bool {
        RecordingSessionManager.shared.currentSession != nil
    }

    /// Start a recording session
    func startRecording() {
        guard !isRecording else {
            Logger.shared.warning("[DeviceManager] Recording already in progress")
            return
        }

        do {
            let session = try RecordingSessionManager.shared.startSession(
                deviceID: deviceUUID?.uuidString,
                deviceName: deviceName
            )
            Logger.shared.info("[DeviceManager] ✅ Started recording session | ID: \(session.id) | Device: \(deviceName)")
        } catch {
            Logger.shared.error("[DeviceManager] ❌ Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Stop the current recording session
    func stopRecording() {
        guard isRecording else {
            Logger.shared.debug("[DeviceManager] No recording in progress")
            return
        }

        do {
            try RecordingSessionManager.shared.stopSession()
            Logger.shared.info("[DeviceManager] ✅ Stopped recording session")
        } catch {
            Logger.shared.error("[DeviceManager] ❌ Failed to stop recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Convenience Methods

    /// Toggle scanning on/off
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            Task { await startScanning() }
        }
    }

    /// Refresh scan (stop and restart)
    func refreshScan() {
        stopScanning()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            await startScanning()
        }
    }

    /// Clear all sensor history
    func clearHistory() {
        Task { @MainActor in
            allSensorReadings.removeAll()
            latestReadings.removeAll()
            Logger.shared.info("[DeviceManager] Cleared all sensor history")
        }
    }

    /// Computed sensor data tuple (legacy compatibility)
    var sensorData: (batteryLevel: Int, firmwareVersion: String, deviceUUID: UInt64) {
        let battery = Int(batteryLevel)
        let uuid = deviceUUID.map { UInt64($0.uuidString.hash.magnitude) } ?? 0
        return (battery, "1.0.0", uuid)
    }

    // MARK: - Private Helper Methods

    /// Convert sensor readings to legacy SensorData format
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
    }
}

// MARK: - Historical Metrics Extension

extension DeviceManager {
    /// Get historical metrics for a time range
    func getHistoricalMetrics(for range: TimeRange) -> HistoricalMetrics? {
        guard !sensorDataHistory.isEmpty else { return nil }
        return HistoricalDataAggregator.aggregate(
            data: sensorDataHistory,
            for: range,
            endDate: Date()
        )
    }
}
