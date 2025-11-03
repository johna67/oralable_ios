//
//  SensorReading.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Unified sensor reading model for all devices
//

import Foundation

/// Unified sensor reading structure for all devices
struct SensorReading: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier
    let id: UUID
    
    /// Type of sensor that produced this reading
    let sensorType: SensorType
    
    /// Raw sensor value
    let value: Double
    
    /// Timestamp when reading was captured
    let timestamp: Date
    
    /// Optional device identifier
    let deviceId: String?
    
    /// Optional quality indicator (0.0 - 1.0)
    let quality: Double?
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        sensorType: SensorType,
        value: Double,
        timestamp: Date = Date(),
        deviceId: String? = nil,
        quality: Double? = nil
    ) {
        self.id = id
        self.sensorType = sensorType
        self.value = value
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.quality = quality
    }
    
    // MARK: - Computed Properties
    
    /// Formatted value string with unit
    var formattedValue: String {
        switch sensorType {
        case .temperature:
            return String(format: "%.1f %@", value, sensorType.unit)
        case .heartRate, .spo2, .battery:
            return String(format: "%.0f %@", value, sensorType.unit)
        case .ppgRed, .ppgInfrared, .ppgGreen, .emg:
            return String(format: "%.0f %@", value, sensorType.unit)
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return String(format: "%.3f %@", value, sensorType.unit)
        case .muscleActivity:
            return String(format: "%.1f %@", value, sensorType.unit)
        }
    }
    
    /// Whether this reading is valid
    var isValid: Bool {
        // Check if value is finite
        guard value.isFinite else { return false }
        
        // Check sensor-specific ranges
        switch sensorType {
        case .heartRate:
            return value >= 30 && value <= 250
        case .spo2:
            return value >= 50 && value <= 100
        case .temperature:
            return value >= 20 && value <= 45
        case .battery:
            return value >= 0 && value <= 100
        case .ppgRed, .ppgInfrared, .ppgGreen:
            return value >= 0
        case .emg:
            return value >= 0
        case .accelerometerX, .accelerometerY, .accelerometerZ:
            return value >= -20 && value <= 20
        case .muscleActivity:
            return value >= 0
        }
    }
    
    // MARK: - Static Helpers
    
    /// Create a mock reading for testing
    static func mock(
        sensorType: SensorType,
        value: Double? = nil
    ) -> SensorReading {
        let mockValue = value ?? sensorType.mockValue
        return SensorReading(
            sensorType: sensorType,
            value: mockValue,
            deviceId: "mock-device",
            quality: 0.95
        )
    }
}

// MARK: - SensorType Mock Values

extension SensorType {
    /// Default mock value for testing
    var mockValue: Double {
        switch self {
        case .heartRate: return 72
        case .spo2: return 98
        case .temperature: return 36.5
        case .battery: return 85
        case .ppgRed: return 2048
        case .ppgInfrared: return 1856
        case .ppgGreen: return 2240
        case .emg: return 450
        case .accelerometerX: return 0.05
        case .accelerometerY: return -0.12
        case .accelerometerZ: return 9.81
        case .muscleActivity: return 520
        }
    }
}

// MARK: - Array Extension

extension Array where Element == SensorReading {
    
    /// Get most recent reading for a sensor type
    func latest(for sensorType: SensorType) -> SensorReading? {
        self
            .filter { $0.sensorType == sensorType }
            .max { $0.timestamp < $1.timestamp }
    }
    
    /// Get readings within a time range
    func readings(
        for sensorType: SensorType,
        from startDate: Date,
        to endDate: Date
    ) -> [SensorReading] {
        self.filter {
            $0.sensorType == sensorType &&
            $0.timestamp >= startDate &&
            $0.timestamp <= endDate
        }
    }
    
    /// Calculate average value for a sensor type
    func average(for sensorType: SensorType) -> Double? {
        let readings = self.filter { $0.sensorType == sensorType && $0.isValid }
        guard !readings.isEmpty else { return nil }
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct SensorReadingPreview: View {
    
    // Create sample readings
    let readings: [SensorReading] = [
        .mock(sensorType: .heartRate),
        .mock(sensorType: .spo2),
        .mock(sensorType: .temperature),
        .mock(sensorType: .battery),
        .mock(sensorType: .ppgInfrared),
        .mock(sensorType: .emg),
        .mock(sensorType: .accelerometerX)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Sensor Readings") {
                    ForEach(readings) { reading in
                        HStack {
                            Image(systemName: reading.sensorType.iconName)
                                .font(.system(size: DesignSystem.Sizing.Icon.lg))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reading.sensorType.displayName)
                                    .font(DesignSystem.Typography.bodyLarge)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text("Device: \(reading.deviceId ?? "Unknown")")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(reading.formattedValue)
                                    .font(DesignSystem.Typography.labelLarge)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text(reading.isValid ? "Valid" : "Invalid")
                                    .font(DesignSystem.Typography.captionSmall)
                                    .foregroundColor(reading.isValid ? DesignSystem.Colors.success : DesignSystem.Colors.error)
                            }
                        }
                        .padding(.vertical, DesignSystem.Spacing.xs)
                    }
                }
                
                Section("Array Extensions") {
                    if let avgHeartRate = readings.average(for: .heartRate) {
                        HStack {
                            Text("Average Heart Rate")
                                .font(DesignSystem.Typography.bodyMedium)
                            Spacer()
                            Text(String(format: "%.0f bpm", avgHeartRate))
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    if let latest = readings.latest(for: .emg) {
                        HStack {
                            Text("Latest EMG Reading")
                                .font(DesignSystem.Typography.bodyMedium)
                            Spacer()
                            Text(latest.formattedValue)
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Section("Validation Tests") {
                    ValidationTest(
                        label: "Valid Heart Rate",
                        reading: SensorReading(sensorType: .heartRate, value: 72)
                    )
                    ValidationTest(
                        label: "Invalid Heart Rate (too low)",
                        reading: SensorReading(sensorType: .heartRate, value: 20)
                    )
                    ValidationTest(
                        label: "Invalid Heart Rate (too high)",
                        reading: SensorReading(sensorType: .heartRate, value: 300)
                    )
                }
            }
            .navigationTitle("Sensor Readings")
            .background(DesignSystem.Colors.backgroundPrimary)
        }
    }
}

struct ValidationTest: View {
    let label: String
    let reading: SensorReading
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
            Spacer()
            Image(systemName: reading.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(reading.isValid ? DesignSystem.Colors.success : DesignSystem.Colors.error)
            Text(reading.formattedValue)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

struct SensorReading_Previews: PreviewProvider {
    static var previews: some View {
        SensorReadingPreview()
    }
}

#endif
