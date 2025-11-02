//
//  SpO2Calculator.swift
//  OralableApp
//
//  Created by John A Cogan on 02/11/2025.
//


//
//  SpO2Calculator.swift
//  OralableApp
//
//  Created by Assistant on October 28, 2025.
//  Purpose: Calculate blood oxygen saturation (SpO2) from PPG signals
//

import Foundation

/// Calculates SpO2 (blood oxygen saturation) from red and infrared PPG signals
/// Uses ratio-of-ratios method for pulse oximetry
class SpO2Calculator {
    
    // MARK: - Constants
    
    /// Minimum number of samples required for calculation (3 seconds at 50 Hz)
    private let minSamplesRequired = 150
    
    /// Valid SpO2 range (percentage)
    private let validSpO2Range: ClosedRange<Double> = 70.0...100.0
    
    /// Minimum acceptable signal quality for SpO2 calculation
    private let minQualityThreshold: Double = 0.6
    
    /// Smoothing window size for noise reduction
    private let smoothingWindow = 10
    
    // MARK: - Public Methods
    
    /// Calculate SpO2 and quality from PPG samples
    /// - Parameters:
    ///   - redSamples: Array of red light PPG values
    ///   - irSamples: Array of infrared light PPG values
    /// - Returns: Tuple of (SpO2 percentage, quality score) or nil if calculation not possible
    func calculateSpO2WithQuality(redSamples: [Int32], irSamples: [Int32]) -> (spo2: Double, quality: Double)? {
        
        // Validate input
        guard redSamples.count >= minSamplesRequired,
              irSamples.count >= minSamplesRequired,
              redSamples.count == irSamples.count else {
            return nil
        }
        
        // Convert to Double arrays for processing
        let red = redSamples.map { Double($0) }
        let ir = irSamples.map { Double($0) }
        
        // Step 1: Apply smoothing to reduce noise
        let smoothedRed = applyMovingAverage(signal: red, windowSize: smoothingWindow)
        let smoothedIR = applyMovingAverage(signal: ir, windowSize: smoothingWindow)
        
        // Step 2: Calculate DC components (average values)
        let dcRed = calculateMean(smoothedRed)
        let dcIR = calculateMean(smoothedIR)
        
        guard dcRed > 0, dcIR > 0 else {
            return nil
        }
        
        // Step 3: Calculate AC components (peak-to-peak amplitudes)
        let acRed = calculatePeakToPeak(smoothedRed)
        let acIR = calculatePeakToPeak(smoothedIR)
        
        guard acRed > 0, acIR > 0 else {
            return nil
        }
        
        // Step 4: Calculate R value (ratio of ratios)
        // R = (AC_red / DC_red) / (AC_ir / DC_ir)
        let ratioRed = acRed / dcRed
        let ratioIR = acIR / dcIR
        
        guard ratioIR > 0 else {
            return nil
        }
        
        let rValue = ratioRed / ratioIR
        
        // Step 5: Convert R to SpO2 using empirical calibration curve
        // SpO2 = 110 - 25 * R (simplified linear approximation)
        // More accurate: SpO2 = -45.060 * R^2 + 30.354 * R + 94.845
        let spo2 = -45.060 * pow(rValue, 2) + 30.354 * rValue + 94.845
        
        // Step 6: Calculate signal quality
        let quality = calculateSignalQuality(
            redSamples: smoothedRed,
            irSamples: smoothedIR,
            acRed: acRed,
            acIR: acIR,
            dcRed: dcRed,
            dcIR: dcIR
        )
        
        // Step 7: Validate results
        guard validSpO2Range.contains(spo2),
              quality >= minQualityThreshold else {
            return nil
        }
        
        // Round to 1 decimal place
        let roundedSpO2 = round(spo2 * 10) / 10
        let roundedQuality = round(quality * 100) / 100
        
        return (roundedSpO2, roundedQuality)
    }
    
    /// Quick calculation without quality assessment
    /// - Parameters:
    ///   - redSamples: Array of red light PPG values
    ///   - irSamples: Array of infrared light PPG values
    /// - Returns: SpO2 percentage or nil if calculation not possible
    func calculateSpO2(redSamples: [Int32], irSamples: [Int32]) -> Double? {
        guard let result = calculateSpO2WithQuality(redSamples: redSamples, irSamples: irSamples) else {
            return nil
        }
        return result.spo2
    }
    
    // MARK: - Private Helper Methods
    
    /// Apply moving average filter for noise reduction
    private func applyMovingAverage(signal: [Double], windowSize: Int) -> [Double] {
        guard signal.count >= windowSize else {
            return signal
        }
        
        var smoothed = [Double]()
        
        for i in 0..<signal.count {
            let start = max(0, i - windowSize / 2)
            let end = min(signal.count, i + windowSize / 2 + 1)
            let window = Array(signal[start..<end])
            let average = window.reduce(0.0, +) / Double(window.count)
            smoothed.append(average)
        }
        
        return smoothed
    }
    
    /// Calculate mean of signal
    private func calculateMean(_ signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }
        return signal.reduce(0.0, +) / Double(signal.count)
    }
    
    /// Calculate peak-to-peak amplitude (AC component)
    private func calculatePeakToPeak(_ signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }
        
        let maxValue = signal.max() ?? 0
        let minValue = signal.min() ?? 0
        
        return maxValue - minValue
    }
    
    /// Calculate standard deviation
    private func calculateStandardDeviation(_ signal: [Double]) -> Double {
        guard signal.count > 1 else { return 0 }
        
        let mean = calculateMean(signal)
        let squaredDifferences = signal.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0.0, +) / Double(signal.count - 1)
        
        return sqrt(variance)
    }
    
    /// Calculate signal quality score (0.0 to 1.0)
    private func calculateSignalQuality(
        redSamples: [Double],
        irSamples: [Double],
        acRed: Double,
        acIR: Double,
        dcRed: Double,
        dcIR: Double
    ) -> Double {
        
        // Factor 1: Signal-to-noise ratio (SNR)
        let snrRed = acRed / dcRed
        let snrIR = acIR / dcIR
        let avgSNR = (snrRed + snrIR) / 2.0
        let snrScore = min(1.0, avgSNR / 0.1) // Normalize to 0-1, assuming 0.1 is good SNR
        
        // Factor 2: Signal stability (inverse of coefficient of variation)
        let stdRed = calculateStandardDeviation(redSamples)
        let stdIR = calculateStandardDeviation(irSamples)
        let cvRed = dcRed > 0 ? stdRed / dcRed : 1.0
        let cvIR = dcIR > 0 ? stdIR / dcIR : 1.0
        let stability = 1.0 - min(1.0, (cvRed + cvIR) / 2.0)
        
        // Factor 3: Signal amplitude (both channels should have reasonable amplitude)
        let amplitudeScore = min(1.0, (acRed + acIR) / 20000.0) // Normalize based on expected range
        
        // Factor 4: DC level adequacy (signals should not be saturated or too weak)
        let dcRedScore = (dcRed > 10000 && dcRed < 500000) ? 1.0 : 0.5
        let dcIRScore = (dcIR > 10000 && dcIR < 500000) ? 1.0 : 0.5
        let dcScore = (dcRedScore + dcIRScore) / 2.0
        
        // Weighted combination of quality factors
        let quality = (
            snrScore * 0.4 +           // 40% weight on SNR
            stability * 0.3 +           // 30% weight on stability
            amplitudeScore * 0.2 +      // 20% weight on amplitude
            dcScore * 0.1               // 10% weight on DC levels
        )
        
        return max(0.0, min(1.0, quality))
    }
}


