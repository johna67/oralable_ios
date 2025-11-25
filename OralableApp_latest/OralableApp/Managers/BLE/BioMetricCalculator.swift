//
//  BioMetricCalculator.swift
//  OralableApp
//
//  Created: November 19, 2025
//  Responsibility: Calculate derived biometric metrics from sensor data
//  - Heart rate calculation from PPG (using HeartRateCalculator)
//  - SpO2 calculation from Red/IR ratio
//  - Signal quality assessment
//  - Throttled calculation (500ms intervals) to prevent UI freezes
//

import Foundation
import Combine

/// Calculates biometric metrics from sensor data with throttling to prevent performance issues
@MainActor
class BioMetricCalculator: ObservableObject {

    // MARK: - Published Properties

    @Published var heartRate: Int = 0
    @Published var spO2: Int = 0
    @Published var heartRateQuality: Double = 0.0

    // MARK: - Private Properties

    private let heartRateCalculator = HeartRateCalculator()
    private var lastHRCalculation: Date = Date.distantPast
    private var lastSpO2Calculation: Date = Date.distantPast
    private let calculationInterval: TimeInterval = 0.5  // Only calculate every 500ms

    #if DEBUG
    private var hrLogCounter = 0  // Counter for heart rate logging
    private var spo2LogCounter = 0  // Counter for SpO2 logging
    #endif

    // MARK: - Initialization

    init() {
        Logger.shared.info("[BioMetricCalculator] Initialized")
    }

    // MARK: - Heart Rate Calculation

    /// Calculate heart rate from PPG IR samples
    /// - Parameters:
    ///   - irSamples: Array of IR PPG values
    ///   - processor: SensorDataProcessor to update history
    ///   - healthKitWriter: Optional closure to write to HealthKit
    /// - Returns: Heart rate result if calculation was performed, nil if throttled
    func calculateHeartRate(
        irSamples: [UInt32],
        processor: SensorDataProcessor,
        healthKitWriter: ((Double) -> Void)? = nil
    ) -> HeartRateResult? {
        // Throttle calculation to prevent UI freeze
        let now = Date()
        guard now.timeIntervalSince(lastHRCalculation) >= calculationInterval else {
            return nil
        }

        guard !irSamples.isEmpty else {
            return nil
        }

        // Perform FFT-based heart rate calculation
        guard let hrResult = heartRateCalculator.calculateHeartRate(irSamples: irSamples) else {
            return nil
        }

        // Update published properties
        heartRate = Int(hrResult.bpm)
        heartRateQuality = hrResult.quality
        lastHRCalculation = now

        // Log periodically (every 50th calculation)
        #if DEBUG
        hrLogCounter += 1
        if hrLogCounter >= 50 {
            Logger.shared.info("[BioMetricCalculator] ❤️ Heart Rate: \(heartRate) bpm | Quality: \(String(format: "%.2f", hrResult.quality)) | \(hrResult.qualityLevel.description)")
            hrLogCounter = 0
        }
        #endif

        // Add to history
        let hrData = HeartRateData(bpm: hrResult.bpm, quality: hrResult.quality, timestamp: now)
        processor.heartRateHistory.append(hrData)

        // Write to HealthKit if authorized
        healthKitWriter?(hrResult.bpm)

        return hrResult
    }

    // MARK: - SpO2 Calculation

    /// Calculate SpO2 from Red/IR PPG ratio
    /// - Parameters:
    ///   - red: Red PPG value
    ///   - ir: Infrared PPG value
    ///   - processor: SensorDataProcessor to update history
    ///   - healthKitWriter: Optional closure to write to HealthKit
    /// - Returns: SpO2 percentage if calculation was performed, nil if throttled or invalid data
    func calculateSpO2(
        red: Int32,
        ir: Int32,
        processor: SensorDataProcessor,
        healthKitWriter: ((Double) -> Void)? = nil
    ) -> Double? {
        // Throttle calculation to prevent UI freeze
        let now = Date()
        guard now.timeIntervalSince(lastSpO2Calculation) >= calculationInterval else {
            return nil
        }

        // Validate inputs
        guard red > 1000 && ir > 1000 else {
            return nil
        }

        // Calculate SpO2 using simplified ratio method
        // SpO2 = 110 - 25 * (Red/IR ratio)
        let ratio = Double(red) / Double(ir)
        let calculatedSpO2 = max(70, min(100, 110 - 25 * ratio))

        // Update published properties
        spO2 = Int(calculatedSpO2)
        lastSpO2Calculation = now

        // Log periodically (every 50th calculation)
        #if DEBUG
        spo2LogCounter += 1
        if spo2LogCounter >= 50 {
            Logger.shared.info("[BioMetricCalculator] 🫁 SpO2: \(spO2)% | Ratio: \(String(format: "%.3f", ratio))")
            spo2LogCounter = 0
        }
        #endif

        // Add to history
        let spo2Data = SpO2Data(percentage: calculatedSpO2, quality: 0.8, timestamp: now)
        processor.spo2History.append(spo2Data)

        // Write to HealthKit if authorized
        healthKitWriter?(calculatedSpO2)

        return calculatedSpO2
    }

    /// Calculate SpO2 from grouped PPG values
    /// - Parameters:
    ///   - groupedValues: Dictionary of PPG values grouped by timestamp
    ///   - processor: SensorDataProcessor to update history
    ///   - healthKitWriter: Optional closure to write to HealthKit
    /// - Returns: SpO2 percentage if calculation was performed
    func calculateSpO2FromGrouped(
        groupedValues: [Date: (red: Int32, ir: Int32, green: Int32)],
        processor: SensorDataProcessor,
        healthKitWriter: ((Double) -> Void)? = nil
    ) -> Double? {
        guard let latest = groupedValues.values.first else {
            return nil
        }

        return calculateSpO2(
            red: latest.red,
            ir: latest.ir,
            processor: processor,
            healthKitWriter: healthKitWriter
        )
    }

    // MARK: - Signal Quality Assessment

    /// Assess signal quality from PPG data
    /// - Parameter ppgValues: Array of PPG values
    /// - Returns: Quality score between 0 and 1
    func assessSignalQuality(_ ppgValues: [Double]) -> Double {
        guard !ppgValues.isEmpty else {
            return 0.0
        }

        // Calculate signal-to-noise ratio (simplified)
        let mean = ppgValues.reduce(0, +) / Double(ppgValues.count)
        let variance = ppgValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(ppgValues.count)
        let stdDev = sqrt(variance)

        // Normalize to 0-1 range (higher std dev = better signal in PPG)
        let quality = min(1.0, stdDev / mean)

        return quality
    }

    // MARK: - Reset Methods

    /// Reset all biometric calculations
    func reset() {
        heartRate = 0
        spO2 = 0
        heartRateQuality = 0.0
        lastHRCalculation = Date.distantPast
        lastSpO2Calculation = Date.distantPast
        Logger.shared.info("[BioMetricCalculator] Reset all metrics")
    }
}
