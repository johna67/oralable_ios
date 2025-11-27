//
//  BiometricDataProvider.swift
//  OralableApp
//
//  Created: Refactoring Phase 3 - Breaking Down God Objects
//  Purpose: Protocol for biometric calculations, reducing OralableBLE's responsibilities
//

import Foundation
import Combine

/// Protocol for providing calculated biometric data
/// Extracts health metric calculation responsibilities from OralableBLE
@MainActor
protocol BiometricDataProvider: AnyObject {
    // MARK: - Calculated Biometrics

    /// Current heart rate in beats per minute
    var heartRate: Int { get }

    /// Current blood oxygen saturation percentage (SpO2)
    var spO2: Int { get }

    /// Quality indicator for heart rate calculation (0.0 - 1.0)
    var heartRateQuality: Double { get }

    // MARK: - Publishers for Reactive UI

    var heartRatePublisher: Published<Int>.Publisher { get }
    var spO2Publisher: Published<Int>.Publisher { get }
    var heartRateQualityPublisher: Published<Double>.Publisher { get }
}

// MARK: - Default Values

extension BiometricDataProvider {
    /// Default heart rate when no data available
    static var defaultHeartRate: Int { 0 }

    /// Default SpO2 when no data available
    static var defaultSpO2: Int { 0 }

    /// Default quality when no data available
    static var defaultQuality: Double { 0.0 }
}
