//
//  SharedSensorModels.swift
//  OralableForDentists
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

    // PPG data
    let ppgRed: Int32
    let ppgIR: Int32
    let ppgGreen: Int32

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
