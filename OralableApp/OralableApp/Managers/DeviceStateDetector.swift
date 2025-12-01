//
//  DeviceStateDetector.swift
//  OralableApp
//
//  Created: November 5, 2025
//  Detects device state based on sensor data analysis
//

import Foundation

// MARK: - Imports
// Using canonical DeviceState and DeviceStateResult from Models/DeviceState.swift

/// Detects device state based on sensor readings
@MainActor
class DeviceStateDetector: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentState: DeviceStateResult?
    @Published var stateHistory: [DeviceStateResult] = []
    @Published var isCalibrated: Bool = false
    @Published var calibrationProgress: Double = 0.0
    
    // MARK: - Configuration
    
    private let historyLimit = 100
    private let analysisWindowSize = 10 // Number of recent readings to analyze
    private let calibrationSamplesNeeded = 30 // Samples needed for calibration
    
    // MARK: - Calibration/Baseline Storage
    
    private var baselineMetrics: BaselineMetrics?
    private var calibrationSamples: [DeviceMetrics] = []
    
    private struct BaselineMetrics {
        // Baseline values when on muscle in good position
        let baselineTemperature: Double
        let baselinePPG: Double
        let baselineMovement: Double
        let baselinePPGVariability: Double
        
        // Acceptable ranges (mean ± 2 std dev)
        let temperatureRange: ClosedRange<Double>
        let ppgRange: ClosedRange<Double>
        let movementRange: ClosedRange<Double>
        
        let calibrationDate: Date
        let sampleCount: Int
    }
    
    // MARK: - Thresholds
    
    private struct Thresholds {
        // Battery
        static let chargingBatteryMin = 95 // Battery level when likely charging
        static let batteryIncreaseRate = 2.0 // % increase per minute when charging
        
        // Temperature
        static let bodyTemperatureMin = 30.0 // °C - minimum for being on body
        static let bodyTemperatureMax = 38.0 // °C - maximum realistic body temp
        static let ambientTemperatureMax = 28.0 // °C - typical room temperature
        static let temperatureStabilityThreshold = 0.5 // °C change for "stable"
        
        // Accelerometer (magnitude in raw units, typically 16384 = 1g)
        // Your device reads ~17000-17500 when stationary
        static let idleMovementMax = 18000.0 // Raw units - device is stationary (±500 from 17000)
        static let normalMovementMax = 20000.0 // Raw units - gentle movement
        static let activeMovementMin = 22000.0 // Raw units - active movement
        static let movementVariabilityThreshold = 1500.0 // Raw units - variation threshold for motion detection
        
        // PPG
        static let ppgSignalMin = 1000 // Minimum valid PPG signal
        static let ppgSignalMax = 100000 // Maximum valid PPG signal
        static let ppgVariabilityMin = 0.02 // Minimum variation (as ratio) for valid signal
    }
    
    // MARK: - State Detection
    
    /// Analyzes sensor data to determine device state
    func analyzeDeviceState(sensorData: [SensorData]) -> DeviceStateResult? {
        guard !sensorData.isEmpty else {
            return DeviceStateResult(
                state: .unknown,
                confidence: 0.0,
                timestamp: Date(),
                details: ["reason": "No sensor data available"]
            )
        }
        
        // Get recent data window
        let recentData = Array(sensorData.suffix(analysisWindowSize))
        
        // Extract metrics
        let metrics = extractMetrics(from: recentData)
        
        // Determine state based on metrics
        let result = determineState(from: metrics)
        
        // Update state history
        DispatchQueue.main.async {
            self.currentState = result
            self.stateHistory.append(result)
            
            if self.stateHistory.count > self.historyLimit {
                self.stateHistory.removeFirst(self.stateHistory.count - self.historyLimit)
            }
        }
        
        return result
    }
    
    // MARK: - Metrics Extraction
    
    private struct DeviceMetrics {
        // Battery
        let averageBattery: Double
        let batteryTrend: Double // Positive = increasing, Negative = decreasing
        let isHighBattery: Bool
        
        // Temperature
        let averageTemperature: Double
        let temperatureStability: Double // Standard deviation
        let isBodyTemperature: Bool
        let isAmbientTemperature: Bool
        
        // Accelerometer
        let averageMovement: Double
        let movementVariability: Double
        let isStationary: Bool
        let isActivelyMoving: Bool
        
        // PPG
        let averagePPGIR: Double
        let ppgVariability: Double
        let hasValidPPGSignal: Bool
        let ppgQuality: Double
        
        // Heart Rate (derived)
        let hasHeartRate: Bool
        let averageHeartRate: Double?
    }
    
    private func extractMetrics(from data: [SensorData]) -> DeviceMetrics {
        // Battery analysis
        let batteryLevels = data.map { Double($0.battery.percentage) }
        let avgBattery = batteryLevels.reduce(0, +) / Double(batteryLevels.count)
        let batteryTrend = batteryLevels.count > 1 ? batteryLevels.last! - batteryLevels.first! : 0
        let isHighBattery = avgBattery >= Double(Thresholds.chargingBatteryMin)
        
        // Temperature analysis
        let temperatures = data.map { $0.temperature.celsius }
        let avgTemp = temperatures.reduce(0, +) / Double(temperatures.count)
        let tempStability = standardDeviation(temperatures)
        let isBodyTemp = avgTemp >= Thresholds.bodyTemperatureMin && avgTemp <= Thresholds.bodyTemperatureMax
        let isAmbient = avgTemp < Thresholds.ambientTemperatureMax
        
        // Accelerometer analysis
        let movements = data.map { $0.accelerometer.magnitude }
        let avgMovement = movements.reduce(0, +) / Double(movements.count)
        let movementVariability = standardDeviation(movements)
        let isStationary = avgMovement < Thresholds.idleMovementMax
        let isActive = avgMovement > Thresholds.activeMovementMin
        
        // PPG analysis
        let ppgIRValues = data.map { Double($0.ppg.ir) }
        let avgPPG = ppgIRValues.reduce(0, +) / Double(ppgIRValues.count)
        let ppgVar = calculateVariability(ppgIRValues)
        let hasValidPPG = avgPPG > Double(Thresholds.ppgSignalMin) && 
                         avgPPG < Double(Thresholds.ppgSignalMax) &&
                         ppgVar > Thresholds.ppgVariabilityMin
        let ppgQual = calculatePPGQuality(ppgIRValues)
        
        // Heart rate analysis
        let heartRates = data.compactMap { $0.heartRate?.bpm }
        let hasHR = !heartRates.isEmpty
        let avgHR = hasHR ? heartRates.reduce(0, +) / Double(heartRates.count) : nil
        
        return DeviceMetrics(
            averageBattery: avgBattery,
            batteryTrend: batteryTrend,
            isHighBattery: isHighBattery,
            averageTemperature: avgTemp,
            temperatureStability: tempStability,
            isBodyTemperature: isBodyTemp,
            isAmbientTemperature: isAmbient,
            averageMovement: avgMovement,
            movementVariability: movementVariability,
            isStationary: isStationary,
            isActivelyMoving: isActive,
            averagePPGIR: avgPPG,
            ppgVariability: ppgVar,
            hasValidPPGSignal: hasValidPPG,
            ppgQuality: ppgQual,
            hasHeartRate: hasHR,
            averageHeartRate: avgHR
        )
    }
    
    // MARK: - State Determination Logic
    
    private func determineState(from metrics: DeviceMetrics) -> DeviceStateResult {
        var confidence: Double = 0.5
        var details: [String: Any] = [:]
        
        // If calibrated, check against baseline first
        if let baseline = baselineMetrics {
            let (isNormal, deviations) = isWithinNormalRange(metrics: metrics)
            
            if isNormal && metrics.isStationary {
                // Metrics match calibrated baseline - high confidence "On Muscle"
                confidence = 0.90
                
                // Add extra confidence if heart rate present
                if metrics.hasHeartRate {
                    confidence = 0.95
                }
                
                details = [
                    "temperature": metrics.averageTemperature,
                    "ppgIR": metrics.averagePPGIR,
                    "movement": metrics.averageMovement,
                    "heartRate": metrics.averageHeartRate as Any,
                    "calibrated": true,
                    "tempDeviation": String(format: "%.2fσ", deviations["temperature"] ?? 0),
                    "ppgDeviation": String(format: "%.2fσ", deviations["ppg"] ?? 0),
                    "movementDeviation": String(format: "%.2fσ", deviations["movement"] ?? 0),
                    "reason": "Metrics match calibrated baseline"
                ]
                
                return DeviceStateResult(
                    state: .onCheek,
                    confidence: min(confidence, 1.0),
                    timestamp: Date(),
                    details: details
                )
            }
        }
        
        // Rule 1: On Charger (High battery + stationary + low/stable temp)
        if metrics.isHighBattery && metrics.batteryTrend >= 0 &&
           metrics.isStationary && !metrics.isBodyTemperature {
            
            confidence = 0.95  // FIXED: Increased from 0.85
            
            // 100% confidence if truly not moving and battery at 100%
            if metrics.averageMovement < Thresholds.idleMovementMax / 2 && metrics.averageBattery >= 99 {
                confidence = 1.0
            }
            // Very high confidence if battery is increasing (actively charging)
            else if metrics.batteryTrend > 1.0 {
                confidence = 0.98
            }
            
            details = [
                "battery": metrics.averageBattery,
                "batteryTrend": metrics.batteryTrend,
                "temperature": metrics.averageTemperature,
                "movement": metrics.averageMovement,
                "reason": "High battery, stationary, ambient temperature"
            ]
            
            return DeviceStateResult(
                state: .onChargerStatic,
                confidence: min(confidence, 1.0),
                timestamp: Date(),
                details: details
            )
        }
        
        // Rule 2: On Muscle/Cheek (Body temp + good PPG + stationary + heart rate)
        if metrics.isBodyTemperature && 
           metrics.hasValidPPGSignal &&
           metrics.isStationary &&
           metrics.ppgQuality > 0.6 {
            
            confidence = 0.75
            
            // Increase confidence if we have heart rate
            if metrics.hasHeartRate {
                confidence += 0.15
            }
            
            // Increase confidence if temperature is stable
            if metrics.temperatureStability < Thresholds.temperatureStabilityThreshold {
                confidence += 0.05
            }
            
            details = [
                "temperature": metrics.averageTemperature,
                "ppgIR": metrics.averagePPGIR,
                "ppgQuality": metrics.ppgQuality,
                "movement": metrics.averageMovement,
                "heartRate": metrics.averageHeartRate as Any,
                "calibrated": false,
                "reason": "Body temperature, valid PPG signal, stationary"
            ]

            return DeviceStateResult(
                state: .onCheek,
                confidence: min(confidence, 1.0),
                timestamp: Date(),
                details: details
            )
        }

        // DEBUG: Log motion detection values
        Logger.shared.debug(" Motion Detection Debug:")
        Logger.shared.debug("   Average Movement: \(metrics.averageMovement) (threshold: \(Thresholds.activeMovementMin))")
        Logger.shared.debug("   Movement Variability: \(metrics.movementVariability) (threshold: \(Thresholds.movementVariabilityThreshold))")
        Logger.shared.debug("   Is Actively Moving: \(metrics.isActivelyMoving)")
        Logger.shared.debug("   Is Stationary: \(metrics.isStationary)")
        
        // Rule 3: In Motion (High movement variability is the key indicator)
        // When moving, the accelerometer magnitude varies significantly even if average stays near 1g
        // Using variability as primary indicator since average magnitude stays ~16384 (1g) at rest
        if metrics.movementVariability > Thresholds.movementVariabilityThreshold {
            confidence = 0.85
            
            details = [
                "movement": metrics.averageMovement,
                "movementVariability": metrics.movementVariability,
                "activeMovementMin": Thresholds.activeMovementMin,
                "variabilityThreshold": Thresholds.movementVariabilityThreshold,
                "reason": "Active movement and high variability detected"
            ]
            
            Logger.shared.warning("🚨 Motion detected: BOTH conditions met")
            
            // Increase confidence for very high variability (active handling/shaking)
            if metrics.movementVariability > Thresholds.movementVariabilityThreshold * 2.0 {
                confidence = 0.95
            }

            return DeviceStateResult(
                state: .inMotion,
                confidence: confidence,
                timestamp: Date(),
                details: details
            )
        }

        // Rule 4: Off Charger Idle (Stationary + low battery or decreasing + ambient temp)
        if metrics.isStationary && 
           !metrics.isHighBattery &&
           !metrics.isBodyTemperature {
            
            confidence = 0.90  // FIXED: Increased from 0.70
            
            // Increase confidence if battery is stable and movement is very low
            if metrics.averageMovement < Thresholds.idleMovementMax / 2 {
                confidence = 1.0  // FIXED: 100% confidence when truly not moving
            }
            
            // Also high confidence if battery is decreasing slowly (device just sitting)
            if metrics.batteryTrend <= 0 && metrics.batteryTrend > -5 {
                confidence = max(confidence, 0.95)
            }
            
            details = [
                "battery": metrics.averageBattery,
                "temperature": metrics.averageTemperature,
                "movement": metrics.averageMovement,
                "reason": "Stationary, not charging, ambient temperature"
            ]
            
            return DeviceStateResult(
                state: .offChargerStatic,
                confidence: min(confidence, 1.0),
                timestamp: Date(),
                details: details
            )
        }
        
        // Default: Unknown state
        confidence = 0.3
        details = [
            "battery": metrics.averageBattery,
            "temperature": metrics.averageTemperature,
            "movement": metrics.averageMovement,
            "ppgIR": metrics.averagePPGIR,
            "reason": "Could not determine state with confidence"
        ]
        
        return DeviceStateResult(
            state: .unknown,
            confidence: confidence,
            timestamp: Date(),
            details: details
        )
    }
    
    // MARK: - Statistical Helpers
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    private func calculateVariability(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        
        let stdDev = standardDeviation(values)
        return stdDev / mean // Coefficient of variation
    }
    
    private func calculatePPGQuality(_ values: [Double]) -> Double {
        guard values.count > 2 else { return 0 }
        
        // Check if values are in valid range
        let inRange = values.filter { 
            $0 > Double(Thresholds.ppgSignalMin) && $0 < Double(Thresholds.ppgSignalMax)
        }
        
        let rangeQuality = Double(inRange.count) / Double(values.count)
        
        // Check for variability (should have some variation if on tissue)
        let variability = calculateVariability(values)
        let variabilityQuality = min(variability / 0.1, 1.0) // Normalize
        
        // Combined quality score
        return (rangeQuality * 0.7) + (variabilityQuality * 0.3)
    }
    
    // MARK: - Public Utilities
    
    /// Get the most stable state over the last N seconds
    func getStableState(overLast seconds: TimeInterval) -> DeviceState? {
        let cutoffTime = Date().addingTimeInterval(-seconds)
        let recentStates = stateHistory.filter { $0.timestamp > cutoffTime }
        
        guard !recentStates.isEmpty else { return nil }
        
        // Count occurrences of each state
        var stateCounts: [DeviceState: Int] = [:]
        for result in recentStates {
            stateCounts[result.state, default: 0] += 1
        }
        
        // Return most common state
        return stateCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Reset detector state
    func reset() {
        currentState = nil
        stateHistory.removeAll()
    }
    
    // MARK: - Calibration Methods
    
    /// Start calibration process - user should have device on muscle in good position
    func startCalibration() {
        calibrationSamples.removeAll()
        isCalibrated = false
        calibrationProgress = 0.0
    }
    
    /// Add sample during calibration
    func addCalibrationSample(sensorData: [SensorData]) {
        guard !sensorData.isEmpty else { return }
        
        let recentData = Array(sensorData.suffix(analysisWindowSize))
        let metrics = extractMetrics(from: recentData)
        
        // Only accept samples that look like they're on muscle
        // (body temp, good PPG, low movement)
        if metrics.isBodyTemperature && 
           metrics.hasValidPPGSignal && 
           metrics.isStationary {
            
            calibrationSamples.append(metrics)
            calibrationProgress = Double(calibrationSamples.count) / Double(calibrationSamplesNeeded)
            
            // Complete calibration when we have enough samples
            if calibrationSamples.count >= calibrationSamplesNeeded {
                completeCalibration()
            }
        }
    }
    
    /// Complete calibration and store baseline metrics
    private func completeCalibration() {
        guard calibrationSamples.count >= calibrationSamplesNeeded else { return }
        
        // Calculate baseline values
        let temperatures = calibrationSamples.map { $0.averageTemperature }
        let ppgValues = calibrationSamples.map { $0.averagePPGIR }
        let movements = calibrationSamples.map { $0.averageMovement }
        let ppgVariabilities = calibrationSamples.map { $0.ppgVariability }
        
        let baselineTemp = temperatures.reduce(0, +) / Double(temperatures.count)
        let baselinePPG = ppgValues.reduce(0, +) / Double(ppgValues.count)
        let baselineMovement = movements.reduce(0, +) / Double(movements.count)
        let baselinePPGVar = ppgVariabilities.reduce(0, +) / Double(ppgVariabilities.count)
        
        // Calculate acceptable ranges (mean ± 2 std dev = 95% confidence interval)
        let tempStdDev = standardDeviation(temperatures)
        let ppgStdDev = standardDeviation(ppgValues)
        let movementStdDev = standardDeviation(movements)
        
        let tempRange = (baselineTemp - 2 * tempStdDev)...(baselineTemp + 2 * tempStdDev)
        let ppgRange = (baselinePPG - 2 * ppgStdDev)...(baselinePPG + 2 * ppgStdDev)
        let movementRange = (baselineMovement - 2 * movementStdDev)...(baselineMovement + 2 * movementStdDev)
        
        baselineMetrics = BaselineMetrics(
            baselineTemperature: baselineTemp,
            baselinePPG: baselinePPG,
            baselineMovement: baselineMovement,
            baselinePPGVariability: baselinePPGVar,
            temperatureRange: tempRange,
            ppgRange: ppgRange,
            movementRange: movementRange,
            calibrationDate: Date(),
            sampleCount: calibrationSamples.count
        )
        
        isCalibrated = true
        calibrationProgress = 1.0
    }
    
    /// Check if current metrics match calibrated baseline
    private func isWithinNormalRange(metrics: DeviceMetrics) -> (isNormal: Bool, deviations: [String: Double]) {
        guard let baseline = baselineMetrics else {
            return (false, ["error": -1.0])
        }
        
        var deviations: [String: Double] = [:]
        
        // Calculate normalized deviations (in standard deviations from baseline)
        let tempDeviation = (metrics.averageTemperature - baseline.baselineTemperature) / 
                           ((baseline.temperatureRange.upperBound - baseline.baselineTemperature) / 2.0)
        
        let ppgDeviation = (metrics.averagePPGIR - baseline.baselinePPG) / 
                          ((baseline.ppgRange.upperBound - baseline.baselinePPG) / 2.0)
        
        let movementDeviation = (metrics.averageMovement - baseline.baselineMovement) / 
                               max((baseline.movementRange.upperBound - baseline.baselineMovement) / 2.0, 1.0)
        
        deviations = [
            "temperature": tempDeviation,
            "ppg": ppgDeviation,
            "movement": movementDeviation
        ]
        
        // Check if within acceptable ranges
        let tempInRange = baseline.temperatureRange.contains(metrics.averageTemperature)
        let ppgInRange = baseline.ppgRange.contains(metrics.averagePPGIR)
        let movementInRange = baseline.movementRange.contains(metrics.averageMovement)
        
        let isNormal = tempInRange && ppgInRange && movementInRange
        
        return (isNormal, deviations)
    }
    
    /// Get calibration status info
    func getCalibrationInfo() -> String? {
        guard let baseline = baselineMetrics else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return """
        Calibrated: \(formatter.string(from: baseline.calibrationDate))
        Samples: \(baseline.sampleCount)
        Baseline Temp: \(String(format: "%.1f°C", baseline.baselineTemperature))
        Baseline PPG: \(String(format: "%.0f", baseline.baselinePPG))
        Baseline Movement: \(String(format: "%.1f mg", baseline.baselineMovement))
        """
    }
    
    /// Clear calibration
    func clearCalibration() {
        baselineMetrics = nil
        calibrationSamples.removeAll()
        isCalibrated = false
        calibrationProgress = 0.0
    }
}
