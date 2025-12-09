//
//  SharedSensorModels.swift
//  OralableForProfessionals
//
//  Sensor data models shared with OralableApp for CloudKit data exchange
//

import Foundation
import Compression

// MARK: - Wellness Session Data (matches consumer app)
// Note: BruxismSessionData name retained for CloudKit backwards compatibility

/// Serializable structure containing oral wellness sensor data from CloudKit
struct BruxismSessionData: Codable {
    let sensorReadings: [SerializableSensorData]
    let recordingCount: Int
    let startDate: Date
    let endDate: Date
}

/// Simplified sensor data structure for deserialization
struct SerializableSensorData: Codable {
    let timestamp: Date

    // Device identification (added Dec 9, 2025)
    // Optional for backwards compatibility with existing CloudKit data
    let deviceType: String?  // "Oralable" or "ANR M40"

    // PPG data (from Oralable device)
    let ppgRed: Int32
    let ppgIR: Int32
    let ppgGreen: Int32

    // EMG data (from ANR M40 device, added Dec 9, 2025)
    // Optional for backwards compatibility
    let emg: Double?

    // Accelerometer data
    let accelX: Int16
    let accelY: Int16
    let accelZ: Int16
    let accelMagnitude: Double

    // Temperature
    let temperatureCelsius: Double

    // Battery
    let batteryPercentage: Int

    // Calculated metrics
    let heartRateBPM: Double?
    let heartRateQuality: Double?
    let spo2Percentage: Double?
    let spo2Quality: Double?

    // MARK: - Device Type Detection

    /// Inferred device type based on data characteristics
    /// For legacy data without deviceType field, we infer from sensor values
    var inferredDeviceType: String {
        // If deviceType is already set, use it
        if let deviceType = deviceType {
            return deviceType
        }

        // Infer from data: Oralable has PPG data, ANR M40 has EMG data
        // If ppgIR > 0, it's from Oralable (PPG values are typically 1000+)
        // If ppgIR == 0 or very low, and we have valid battery/temp, it might be ANR
        if ppgIR > 1000 {
            return "Oralable"
        } else if emg != nil && emg! > 0 {
            return "ANR M40"
        } else if ppgIR > 0 && ppgIR < 1000 {
            // Low ppgIR could be EMG value stored in IR field (legacy ANR data)
            return "ANR M40"
        }

        // Default to Oralable if we can't determine
        return "Oralable"
    }

    /// Whether this is from an ANR M40 device
    var isANRDevice: Bool {
        inferredDeviceType == "ANR M40"
    }

    /// Whether this is from an Oralable device
    var isOralableDevice: Bool {
        inferredDeviceType == "Oralable"
    }

    /// Get EMG value (from dedicated field or inferred from legacy data)
    var emgValue: Double? {
        if let emg = emg, emg > 0 {
            return emg
        }
        // For legacy data, ANR stored EMG in ppgIR field
        if isANRDevice && ppgIR > 0 && ppgIR < 1000 {
            return Double(ppgIR)
        }
        return nil
    }

    /// Get PPG IR value (only valid for Oralable devices)
    var ppgIRValue: Double? {
        if isOralableDevice && ppgIR > 1000 {
            return Double(ppgIR)
        }
        return nil
    }
}

// MARK: - Data Compression Helpers

extension Data {
    /// Decompress data using LZFSE algorithm
    func decompressed(expectedSize: Int) -> Data? {
        guard !isEmpty else { return nil }

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                expectedSize,
                sourcePointer,
                count,
                nil,
                COMPRESSION_LZFSE
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}

// MARK: - HealthKit Data Sharing Types

/// Represents a health data record from CloudKit
struct HealthDataRecord: Codable {
    let recordID: String
    let recordingDate: Date
    let dataType: String
    let measurements: Data
    let sessionDuration: TimeInterval
    let healthKitData: HealthKitDataForSharing?
}

/// HealthKit data structure for sharing between apps
struct HealthKitDataForSharing: Codable {
    let heartRateReadings: [HealthDataReading]
    let spo2Readings: [HealthDataReading]
    let sleepData: SleepDataForSharing?

    var averageHeartRate: Double? {
        guard !heartRateReadings.isEmpty else { return nil }
        return heartRateReadings.map { $0.value }.reduce(0, +) / Double(heartRateReadings.count)
    }

    var averageSpO2: Double? {
        guard !spo2Readings.isEmpty else { return nil }
        return spo2Readings.map { $0.value }.reduce(0, +) / Double(spo2Readings.count)
    }
}

/// Sleep data structure for sharing
struct SleepDataForSharing: Codable {
    let totalSleepMinutes: Int
    let deepSleepMinutes: Int
    let remSleepMinutes: Int
}

/// Health reading type enumeration
enum HealthReadingType: String, Codable {
    case heartRate
    case bloodOxygen
    case sleepAnalysis
}

/// Individual health data reading
struct HealthDataReading: Identifiable, Codable {
    var id: UUID { UUID() }
    let type: HealthReadingType
    let value: Double
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case type, value, timestamp
    }
}
