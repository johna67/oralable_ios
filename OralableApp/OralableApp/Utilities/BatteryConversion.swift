//
//  BatteryConversion.swift
//  OralableApp
//
//  Created by John A Cogan on 04/12/2025.
//


//
//  BatteryConversion.swift
//  OralableApp
//
//  Created: December 3, 2025
//  Purpose: Accurate LiPo battery voltage to percentage conversion
//           using empirical discharge curve instead of linear interpolation
//
//  Installation: Copy to OralableApp/OralableApp/Utilities/
//
//  Usage:
//    let percentage = BatteryConversion.voltageToPercentage(millivolts: 3700)
//    let status = BatteryConversion.batteryStatus(percentage: percentage)
//

import Foundation

// MARK: - Battery Conversion Utilities

/// Converts battery voltage to percentage using empirical LiPo discharge curve
/// Provides more accurate readings than linear interpolation, especially at low charge levels
struct BatteryConversion {
    
    // MARK: - Voltage Constants
    
    /// Fully charged voltage (mV)
    static let voltageMax: Int32 = 4200
    
    /// Empty voltage - do not discharge below this (mV)
    static let voltageMin: Int32 = 3000
    
    /// Low battery warning threshold (mV)
    static let voltageLowWarning: Int32 = 3400
    
    /// Critical battery threshold (mV)
    static let voltageCritical: Int32 = 3200
    
    // MARK: - Discharge Curve
    
    /// Empirical LiPo discharge curve data points
    /// Based on typical single-cell LiPo discharge characteristics
    /// Format: (voltage_mV, percentage)
    private static let dischargeCurve: [(voltage: Int32, percentage: Double)] = [
        (4200, 100.0),
        (4150, 95.0),
        (4110, 90.0),
        (4080, 85.0),
        (4020, 80.0),
        (3980, 75.0),
        (3950, 70.0),
        (3910, 65.0),
        (3870, 60.0),
        (3840, 55.0),
        (3800, 50.0),
        (3760, 45.0),
        (3720, 40.0),
        (3680, 35.0),
        (3650, 30.0),
        (3610, 25.0),
        (3570, 20.0),
        (3500, 15.0),
        (3400, 10.0),
        (3300, 5.0),
        (3200, 2.0),
        (3000, 0.0)
    ]
    
    // MARK: - Conversion Methods
    
    /// Convert battery voltage in millivolts to percentage using discharge curve
    /// - Parameter millivolts: Battery voltage in millivolts (typically 3000-4200)
    /// - Returns: Battery percentage (0.0 to 100.0)
    static func voltageToPercentage(millivolts: Int32) -> Double {
        // Handle edge cases
        if millivolts >= voltageMax {
            return 100.0
        }
        if millivolts <= voltageMin {
            return 0.0
        }
        
        // Find the two curve points that bracket the voltage
        for i in 0..<(dischargeCurve.count - 1) {
            let upper = dischargeCurve[i]
            let lower = dischargeCurve[i + 1]
            
            if millivolts <= upper.voltage && millivolts >= lower.voltage {
                // Linear interpolation between the two points
                let voltageRange = Double(upper.voltage - lower.voltage)
                let percentageRange = upper.percentage - lower.percentage
                let voltageOffset = Double(millivolts - lower.voltage)
                
                let interpolatedPercentage = lower.percentage + (voltageOffset / voltageRange) * percentageRange
                return min(100.0, max(0.0, interpolatedPercentage))
            }
        }
        
        // Fallback (should not reach here)
        return linearPercentage(millivolts: millivolts)
    }
    
    /// Simple linear conversion (for comparison/fallback)
    /// - Parameter millivolts: Battery voltage in millivolts
    /// - Returns: Battery percentage using linear interpolation
    static func linearPercentage(millivolts: Int32) -> Double {
        let voltage = Double(millivolts) / 1000.0
        let percentage = (voltage - 3.0) / (4.2 - 3.0) * 100.0
        return min(100.0, max(0.0, percentage))
    }
    
    /// Convert voltage to percentage with rounding to integer
    /// - Parameter millivolts: Battery voltage in millivolts
    /// - Returns: Battery percentage as integer (0 to 100)
    static func voltageToPercentageInt(millivolts: Int32) -> Int {
        return Int(voltageToPercentage(millivolts: millivolts).rounded())
    }
    
    // MARK: - Status Methods
    
    /// Battery status level enumeration
    enum BatteryStatus: String, Codable {
        case full = "Full"
        case good = "Good"
        case medium = "Medium"
        case low = "Low"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .full, .good: return "green"
            case .medium: return "yellow"
            case .low: return "orange"
            case .critical: return "red"
            }
        }
        
        var systemImageName: String {
            switch self {
            case .full: return "battery.100"
            case .good: return "battery.75"
            case .medium: return "battery.50"
            case .low: return "battery.25"
            case .critical: return "battery.0"
            }
        }
    }
    
    /// Get battery status from percentage
    /// - Parameter percentage: Battery percentage (0-100)
    /// - Returns: BatteryStatus enum value
    static func batteryStatus(percentage: Double) -> BatteryStatus {
        switch percentage {
        case 80...100: return .full
        case 50..<80: return .good
        case 20..<50: return .medium
        case 10..<20: return .low
        default: return .critical
        }
    }
    
    /// Get battery status from voltage
    /// - Parameter millivolts: Battery voltage in millivolts
    /// - Returns: BatteryStatus enum value
    static func batteryStatus(millivolts: Int32) -> BatteryStatus {
        return batteryStatus(percentage: voltageToPercentage(millivolts: millivolts))
    }
    
    /// Check if battery needs charging
    /// - Parameter percentage: Battery percentage
    /// - Returns: true if percentage is below 20%
    static func needsCharging(percentage: Double) -> Bool {
        return percentage < 20.0
    }
    
    /// Check if battery is critically low
    /// - Parameter percentage: Battery percentage
    /// - Returns: true if percentage is below 10%
    static func isCritical(percentage: Double) -> Bool {
        return percentage < 10.0
    }
    
    // MARK: - Formatting
    
    /// Format percentage for display
    /// - Parameter percentage: Battery percentage
    /// - Returns: Formatted string like "85%"
    static func formatPercentage(_ percentage: Double) -> String {
        return String(format: "%.0f%%", percentage)
    }
    
    /// Format voltage for display
    /// - Parameter millivolts: Battery voltage in millivolts
    /// - Returns: Formatted string like "3.85V"
    static func formatVoltage(millivolts: Int32) -> String {
        let volts = Double(millivolts) / 1000.0
        return String(format: "%.2fV", volts)
    }
    
    // MARK: - Comparison Data
    
    /// Generate comparison table between linear and curve-based percentages
    /// Useful for debugging and validation
    static func generateComparisonTable() -> [(voltage: Int32, linear: Double, curve: Double, difference: Double)] {
        var results: [(voltage: Int32, linear: Double, curve: Double, difference: Double)] = []
        
        for voltage in stride(from: voltageMax, through: voltageMin, by: -100) {
            let linear = linearPercentage(millivolts: voltage)
            let curve = voltageToPercentage(millivolts: voltage)
            let diff = curve - linear
            results.append((voltage: voltage, linear: linear, curve: curve, difference: diff))
        }
        
        return results
    }
}

// MARK: - Extension for OralableDevice Integration

extension BatteryConversion {
    
    /// Parse battery data from BLE packet and return percentage
    /// - Parameter data: 4-byte Data containing Int32 millivolts (little-endian)
    /// - Returns: Battery percentage or nil if data is invalid
    static func parseAndConvert(data: Data) -> Double? {
        guard data.count >= 4 else { return nil }
        
        let millivolts = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self)
        }
        
        return voltageToPercentage(millivolts: millivolts)
    }
    
    /// Parse battery data and return both voltage and percentage
    /// - Parameter data: 4-byte Data containing Int32 millivolts
    /// - Returns: Tuple of (millivolts, percentage) or nil if invalid
    static func parseComplete(data: Data) -> (millivolts: Int32, percentage: Double, status: BatteryStatus)? {
        guard data.count >= 4 else { return nil }

        let millivolts = data.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self)
        }

        // Validate voltage is in reasonable range
        guard millivolts >= 2500 && millivolts <= 4500 else { return nil }

        let percentage = voltageToPercentage(millivolts: millivolts)
        let status = batteryStatus(percentage: percentage)

        return (millivolts: millivolts, percentage: percentage, status: status)
    }
}

// MARK: - SwiftUI Color Extension (Optional)

#if canImport(SwiftUI)
import SwiftUI

extension BatteryConversion.BatteryStatus {
    var swiftUIColor: Color {
        switch self {
        case .full, .good: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .critical: return .red
        }
    }
}
#endif
