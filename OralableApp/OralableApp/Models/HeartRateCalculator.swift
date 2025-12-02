//
//  HeartRateCalculator.swift
//  OralableApp
//
//  Created by John A Cogan on 28/10/2025.
//


import Foundation

/// Heart rate calculator using PPG IR signal peak detection
/// Implements real-time BPM calculation with quality assessment
class HeartRateCalculator {
    
    // MARK: - Configuration
    private let samplingRate: Double = 50.0  // Hz (matches CONFIG_PPG_SAMPLES_PER_FRAME=20, frame every 0.4s)
    private let windowSize: Int = 150        // 3 seconds of data (3s * 50Hz)
    private let minPeakDistance: Int = 15    // 0.3s minimum between peaks (max 200 BPM)
    private let maxPeakDistance: Int = 75    // 1.5s maximum between peaks (min 40 BPM)
    
    // Bandpass filter parameters (0.5-4.0 Hz for cardiac frequencies)
    private let lowCutoff: Double = 0.5      // Hz (30 BPM)
    private let highCutoff: Double = 4.0     // Hz (240 BPM)
    
    // Quality thresholds
    private let minQualityThreshold: Double = 0.3
    private let goodQualityThreshold: Double = 0.6
    
    // MARK: - State
    private var signalBuffer: [Double] = []
    private var lastHeartRate: Double?
    private var lastQuality: Double = 0.0

    // Throttle warning messages to prevent log spam
    private var lastWarningTime: Date?
    private let warningThrottleInterval: TimeInterval = 5.0  // Only log warnings every 5 seconds
    
    // MARK: - Public Methods
    
    /// Calculate heart rate from PPG IR samples
    /// - Parameter irSamples: Array of PPG IR values (UInt32)
    /// - Returns: HeartRateResult with BPM and quality metrics, or nil if insufficient data
    func calculateHeartRate(irSamples: [UInt32]) -> HeartRateResult? {
        // Log input for debugging
        Task { @MainActor in
            Logger.shared.info("[HeartRateCalculator] 💓 calculateHeartRate called with \(irSamples.count) samples")
            if let first = irSamples.first, let last = irSamples.last {
                Logger.shared.info("[HeartRateCalculator] 💓 Sample range: first=\(first), last=\(last)")
            }
        }

        // Filter out invalid samples (saturation, zero, or out of range)
        let validSamples = irSamples.filter { sample in
            // Reject zero values (sensor error)
            guard sample > 0 else { return false }

            // Reject saturation values (0x7FFFF = 524287 for 19-bit ADC)
            guard sample < 500000 else { return false }

            // Reject very low values (likely not on tissue)
            guard sample > 1000 else { return false }

            return true
        }

        Task { @MainActor in
            Logger.shared.info("[HeartRateCalculator] 💓 Valid samples: \(validSamples.count)/\(irSamples.count)")
        }

        // Need at least 80% valid samples to proceed
        guard Double(validSamples.count) / Double(irSamples.count) >= 0.8 else {
            Task { @MainActor in
                Logger.shared.warning("[HeartRateCalculator] ❌ Too many invalid samples (\(validSamples.count)/\(irSamples.count)) - need 80%")
            }
            return nil
        }
        
        // Convert UInt32 to Double
        let samples = validSamples.map { Double($0) }
        
        // Check for reasonable signal variability
        guard samples.count >= 3 else { return nil }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count)
        let coefficientOfVariation = sqrt(variance) / mean

        Task { @MainActor in
            Logger.shared.info("[HeartRateCalculator] 💓 Signal stats: mean=\(Int(mean)), CV=\(String(format: "%.4f", coefficientOfVariation))")
        }

        // Signal should have some variability (>0.5%) but not too much (>50%)
        guard coefficientOfVariation > 0.005 && coefficientOfVariation < 0.5 else {
            Task { @MainActor in
                Logger.shared.warning("[HeartRateCalculator] ❌ Poor signal variability (CV: \(String(format: "%.4f", coefficientOfVariation))) - need 0.005-0.5")
            }
            return nil
        }
        
        // Add to buffer
        signalBuffer.append(contentsOf: samples)
        
        // Keep only most recent windowSize samples
        if signalBuffer.count > windowSize {
            signalBuffer.removeFirst(signalBuffer.count - windowSize)
        }
        
        // Need full window for reliable calculation
        guard signalBuffer.count >= windowSize else {
            Task { @MainActor in
                Logger.shared.info("[HeartRateCalculator] 💓 Buffer filling: \(self.signalBuffer.count)/\(self.windowSize)")
            }
            return nil
        }

        // Apply bandpass filter
        let filtered = bandpassFilter(signalBuffer)

        // Detect peaks
        let peaks = detectPeaks(in: filtered)

        Task { @MainActor in
            Logger.shared.info("[HeartRateCalculator] 💓 Detected \(peaks.count) peaks in signal")
        }

        // Calculate heart rate from peaks
        guard let (bpm, quality) = calculateBPMFromPeaks(peaks, signalLength: filtered.count) else {
            Task { @MainActor in
                Logger.shared.warning("[HeartRateCalculator] ❌ calculateBPMFromPeaks returned nil (not enough valid peaks)")
            }
            return nil
        }
        
        // Additional validation: reject physiologically impossible heart rates
        guard bpm >= 40 && bpm <= 180 else {
            if shouldLogWarning() {
                Task { @MainActor in
                    Logger.shared.warning("[HeartRateCalculator] Physiologically impossible BPM: \(bpm)")
                }
            }
            return nil
        }
        
        // If we have a previous heart rate, check for unrealistic jumps
        if let lastBPM = lastHeartRate {
            let change = abs(bpm - lastBPM)
            let percentChange = change / lastBPM
            
            // Reject changes > 30% between readings (too fast for real HR change)
            if percentChange > 0.3 {
                if shouldLogWarning() {
                    Task { @MainActor in
                        Logger.shared.warning("[HeartRateCalculator] Unrealistic jump from \(Int(lastBPM)) to \(Int(bpm)) BPM")
                    }
                }
                // Don't return nil, but reduce quality
                let adjustedQuality = quality * 0.5
                
                return HeartRateResult(
                    bpm: bpm,
                    quality: adjustedQuality,
                    qualityLevel: qualityLevel(from: adjustedQuality),
                    isReliable: adjustedQuality >= minQualityThreshold,
                    timestamp: Date()
                )
            }
        }
        
        // Store for trend analysis
        lastHeartRate = bpm
        lastQuality = quality

        Task { @MainActor in
            Logger.shared.info("[HeartRateCalculator] ✅ Heart Rate: \(Int(bpm)) BPM (quality: \(String(format: "%.2f", quality)))")
        }

        return HeartRateResult(
            bpm: bpm,
            quality: quality,
            qualityLevel: qualityLevel(from: quality),
            isReliable: quality >= minQualityThreshold,
            timestamp: Date()
        )
    }
    
    /// Reset calculator state
    func reset() {
        signalBuffer.removeAll()
        lastHeartRate = nil
        lastQuality = 0.0
    }
    
    // MARK: - Signal Processing
    
    /// Apply bandpass filter (0.5-4.0 Hz) to remove DC offset and high-frequency noise
    private func bandpassFilter(_ signal: [Double]) -> [Double] {
        // Simple implementation: High-pass followed by low-pass
        let highPassed = highPassFilter(signal, cutoff: lowCutoff)
        let bandPassed = lowPassFilter(highPassed, cutoff: highCutoff)
        return bandPassed
    }
    
    /// High-pass filter to remove DC offset and low-frequency drift
    private func highPassFilter(_ signal: [Double], cutoff: Double) -> [Double] {
        let alpha = cutoff / (cutoff + samplingRate)
        var filtered: [Double] = []
        var previousInput = signal[0]
        var previousOutput = 0.0
        
        for sample in signal {
            let output = alpha * (previousOutput + sample - previousInput)
            filtered.append(output)
            previousInput = sample
            previousOutput = output
        }
        
        return filtered
    }
    
    /// Low-pass filter to remove high-frequency noise
    private func lowPassFilter(_ signal: [Double], cutoff: Double) -> [Double] {
        let alpha = (2.0 * .pi * cutoff) / (samplingRate + 2.0 * .pi * cutoff)
        var filtered: [Double] = []
        var previousOutput = signal[0]
        
        for sample in signal {
            let output = previousOutput + alpha * (sample - previousOutput)
            filtered.append(output)
            previousOutput = output
        }
        
        return filtered
    }
    
    // MARK: - Peak Detection
    
    /// Detect peaks in filtered signal using adaptive threshold
    private func detectPeaks(in signal: [Double]) -> [Int] {
        guard signal.count >= windowSize else { return [] }
        
        // Calculate adaptive threshold (0.5 standard deviations above mean)
        let mean = signal.reduce(0, +) / Double(signal.count)
        let variance = signal.map { pow($0 - mean, 2) }.reduce(0, +) / Double(signal.count)
        let stdDev = sqrt(variance)
        let threshold = mean + 0.5 * stdDev
        
        var peaks: [Int] = []
        var lastPeakIndex = -minPeakDistance
        
        // Find local maxima above threshold
        for i in 1..<(signal.count - 1) {
            let current = signal[i]
            let previous = signal[i - 1]
            let next = signal[i + 1]
            
            // Check if local maximum
            if current > previous && current > next && current > threshold {
                // Check minimum distance from last peak
                if i - lastPeakIndex >= minPeakDistance {
                    peaks.append(i)
                    lastPeakIndex = i
                }
            }
        }
        
        return peaks
    }
    
    /// Calculate BPM and quality from detected peaks
    private func calculateBPMFromPeaks(_ peaks: [Int], signalLength: Int) -> (bpm: Double, quality: Double)? {
        // Need at least 2 peaks to calculate intervals
        guard peaks.count >= 2 else {
            return nil
        }
        
        // Calculate inter-peak intervals
        var intervals: [Int] = []
        for i in 1..<peaks.count {
            let interval = peaks[i] - peaks[i-1]
            
            // Filter out intervals outside physiological range
            if interval >= minPeakDistance && interval <= maxPeakDistance {
                intervals.append(interval)
            }
        }
        
        guard intervals.count >= 1 else {
            return nil
        }
        
        // Remove outliers (intervals that deviate more than 30% from median)
        intervals.sort()
        let medianInterval = intervals[intervals.count / 2]
        let filteredIntervals = intervals.filter { interval in
            let deviation = abs(Double(interval - medianInterval)) / Double(medianInterval)
            return deviation < 0.3
        }
        
        guard !filteredIntervals.isEmpty else {
            return nil
        }
        
        // Calculate mean interval and convert to BPM
        let meanInterval = Double(filteredIntervals.reduce(0, +)) / Double(filteredIntervals.count)
        let bpm = (60.0 * samplingRate) / meanInterval
        
        // Calculate quality metric based on interval consistency
        let intervalStdDev = calculateStdDev(filteredIntervals.map { Double($0) })
        let coefficientOfVariation = intervalStdDev / meanInterval
        let quality = max(0.0, min(1.0, 1.0 - coefficientOfVariation))
        
        // Clamp BPM to physiological range
        let clampedBPM = max(40.0, min(180.0, bpm))
        
        return (clampedBPM, quality)
    }
    
    // MARK: - Helper Methods

    /// Check if we should log a warning (throttled to prevent spam)
    private func shouldLogWarning() -> Bool {
        let now = Date()
        if let lastTime = lastWarningTime {
            if now.timeIntervalSince(lastTime) < warningThrottleInterval {
                return false
            }
        }
        lastWarningTime = now
        return true
    }

    /// Calculate standard deviation
    private func calculateStdDev(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    /// Determine quality level from quality metric
    private func qualityLevel(from quality: Double) -> HeartRateQualityLevel {
        if quality >= goodQualityThreshold {
            return .good
        } else if quality >= minQualityThreshold {
            return .fair
        } else {
            return .poor
        }
    }
}

// MARK: - Data Models

/// Heart rate calculation result
struct HeartRateResult {
    let bpm: Double
    let quality: Double              // 0.0 to 1.0
    let qualityLevel: HeartRateQualityLevel
    let isReliable: Bool
    let timestamp: Date
}

/// Quality level classification
enum HeartRateQualityLevel {
    case good    // Quality >= 0.6
    case fair    // Quality >= 0.3
    case poor    // Quality < 0.3
    
    var color: String {
        switch self {
        case .good: return "green"
        case .fair: return "yellow"
        case .poor: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Good Signal"
        case .fair: return "Fair Signal"
        case .poor: return "Poor Signal"
        }
    }
}