import Foundation

/// Shared PPG normalization service used by UI and processors.
/// Keep this internal (no `public` API that references internal SensorData types).
@MainActor
class PPGNormalizationService: ObservableObject {
    static let shared = PPGNormalizationService()

    enum Method: String, CaseIterable {
        case raw = "Raw Values"
        case adaptiveBaseline = "Adaptive Baseline"
        case dynamicRange = "Dynamic Range"
        case heartRateSimulation = "HR Simulation"
        case persistent = "Persistent Smart"
    }

    @Published private var baselineState: BaselineState?
    @Published private var deviceContext: DeviceContext?
    private var lastUpdateTime: Date = Date()

    struct BaselineState {
        let irBaseline: Double
        let redBaseline: Double
        let greenBaseline: Double
        let timestamp: Date
        let confidence: Double
        let sampleCount: Int

        var isStale: Bool {
            Date().timeIntervalSince(timestamp) > 300
        }

        var isReliable: Bool {
            confidence > 0.8 && sampleCount >= 20
        }
    }

    struct DeviceContext {
        let isOnBody: Bool
        let isMoving: Bool
        let temperatureStable: Bool
        let batteryCharging: Bool
        let confidence: Double
        let timestamp: Date

        var isStable: Bool {
            !isMoving && temperatureStable && confidence > 0.7
        }

        var recommendedNormalization: Method {
            if isOnBody && isStable {
                return .persistent
            } else if isStable {
                return .adaptiveBaseline
            } else {
                return .dynamicRange
            }
        }
    }

    // Normalize PPG data for downstream processing/visualization.
    // sensorData is optional context used to decide adaptive/persistent behavior.
    func normalizePPGData(
        _ data: [(timestamp: Date, ir: Double, red: Double, green: Double)],
        method: Method = .persistent,
        sensorData: [SensorData] = []
    ) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {

        guard !data.isEmpty else { return data }

        if !sensorData.isEmpty {
            updateDeviceContext(from: sensorData)
        }

        let actualMethod = method == .persistent ?
            (deviceContext?.recommendedNormalization ?? .adaptiveBaseline) : method

        switch actualMethod {
        case .raw:
            return data
        case .adaptiveBaseline:
            return adaptiveBaselineNormalization(data)
        case .dynamicRange:
            return dynamicRangeNormalization(data)
        case .heartRateSimulation:
            return heartRateSimulationNormalization(data)
        case .persistent:
            return persistentSmartNormalization(data)
        }
    }

    private func updateDeviceContext(from sensorData: [SensorData]) {
        guard !sensorData.isEmpty else { return }

        let recentSamples = Array(sensorData.suffix(10))
        guard recentSamples.count >= 5 else { return }

        let accelerometerVariation = calculateMovementVariation(recentSamples)
        let temperatureChange = calculateTemperatureChange(recentSamples)
        let batteryLevel = recentSamples.last?.battery.percentage ?? 0
        let avgTemperature = recentSamples.map { $0.temperature.celsius }.reduce(0, +) / Double(recentSamples.count)

        let isMoving = accelerometerVariation > 0.3
        let temperatureStable = temperatureChange < 1.0
        let batteryCharging = batteryLevel > 95
        let isOnBody = avgTemperature > 25.0 && !isMoving

        var confidence = 0.5
        if temperatureStable { confidence += 0.2 }
        if !isMoving { confidence += 0.2 }
        if recentSamples.count >= 10 { confidence += 0.1 }

        deviceContext = DeviceContext(
            isOnBody: isOnBody,
            isMoving: isMoving,
            temperatureStable: temperatureStable,
            batteryCharging: batteryCharging,
            confidence: confidence,
            timestamp: Date()
        )
    }

    // MARK: - Normalization implementations
    private func persistentSmartNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let shouldUpdateBaseline = baselineState == nil ||
                                  baselineState!.isStale ||
                                  (deviceContext?.isStable == true && !(baselineState?.isReliable ?? false))

        if shouldUpdateBaseline {
            updatePersistentBaseline(data)
        }

        guard let baseline = baselineState, baseline.isReliable else {
            return adaptiveBaselineNormalization(data)
        }

        return data.map { sample in
            let correctedIR = sample.ir - baseline.irBaseline
            let correctedRed = sample.red - baseline.redBaseline
            let correctedGreen = sample.green - baseline.greenBaseline

            let scalingFactor: Double = deviceContext?.isOnBody == true ? 0.05 : 0.1

            return (
                timestamp: sample.timestamp,
                ir: 120 + (correctedIR * scalingFactor),
                red: 120 + (correctedRed * scalingFactor),
                green: 120 + (correctedGreen * scalingFactor)
            )
        }
    }

    private func updatePersistentBaseline(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) {
        guard let context = deviceContext, context.isStable else {
            return
        }

        let irValues = data.map { $0.ir }.sorted()
        let redValues = data.map { $0.red }.sorted()
        let greenValues = data.map { $0.green }.sorted()

        guard !irValues.isEmpty else { return }

        let medianIndex = irValues.count / 2
        let irBaseline = irValues[medianIndex]
        let redBaseline = redValues[medianIndex]
        let greenBaseline = greenValues[medianIndex]

        let irStd = calculateStandardDeviation(irValues)
        let coefficientOfVariation = irStd / max(1e-9, abs(irBaseline))
        let confidence = max(0.0, min(1.0, 1.0 - (coefficientOfVariation / 0.2)))

        baselineState = BaselineState(
            irBaseline: irBaseline,
            redBaseline: redBaseline,
            greenBaseline: greenBaseline,
            timestamp: Date(),
            confidence: confidence,
            sampleCount: data.count
        )
    }

    private func adaptiveBaselineNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let windowSize = min(10, max(1, data.count / 3))
        guard windowSize > 0 else { return data }

        return data.enumerated().map { index, sample in
            let windowStart = max(0, index - windowSize/2)
            let windowEnd = min(data.count, windowStart + windowSize)
            let window = Array(data[windowStart..<windowEnd])

            let irBaseline = window.map { $0.ir }.reduce(0, +) / Double(window.count)
            let redBaseline = window.map { $0.red }.reduce(0, +) / Double(window.count)
            let greenBaseline = window.map { $0.green }.reduce(0, +) / Double(window.count)

            return (
                timestamp: sample.timestamp,
                ir: 100 + (sample.ir - irBaseline) * 0.1,
                red: 100 + (sample.red - redBaseline) * 0.1,
                green: 100 + (sample.green - greenBaseline) * 0.1
            )
        }
    }

    private func dynamicRangeNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let irValues = data.map { $0.ir }.sorted()
        let redValues = data.map { $0.red }.sorted()
        let greenValues = data.map { $0.green }.sorted()

        func percentile(_ values: [Double], _ p: Double) -> Double {
            let index = Int(Double(values.count - 1) * p)
            return values[max(0, min(index, values.count - 1))]
        }

        let irMin = percentile(irValues, 0.1)
        let irMax = percentile(irValues, 0.9)
        let redMin = percentile(redValues, 0.1)
        let redMax = percentile(redValues, 0.9)
        let greenMin = percentile(greenValues, 0.1)
        let greenMax = percentile(greenValues, 0.9)

        return data.map { sample in
            let irNorm = irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0.5
            let redNorm = redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0.5
            let greenNorm = greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0.5

            return (
                timestamp: sample.timestamp,
                ir: 50 + irNorm * 100,
                red: 50 + redNorm * 100,
                green: 50 + greenNorm * 100
            )
        }
    }

    private func heartRateSimulationNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let irValues = data.map { $0.ir }
        let irMean = irValues.reduce(0, +) / Double(irValues.count)
        let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))

        return data.map { sample in
            let irZ = irStd > 0 ? (sample.ir - irMean) / irStd : 0
            let simulatedHR = 120 + irZ * 20

            return (
                timestamp: sample.timestamp,
                ir: max(60, min(180, simulatedHR)),
                red: sample.red,
                green: sample.green
            )
        }
    }

    func resetPersistentState() {
        baselineState = nil
        deviceContext = nil
    }

    func getStateInfo() -> String {
        var info = "PPG Normalization State:\n"

        if let baseline = baselineState {
            let baselineStr = String(format: "%.0f", baseline.irBaseline)
            let confidencePercent = String(format: "%.1f", baseline.confidence * 100)
            let ageSeconds = Int(Date().timeIntervalSince(baseline.timestamp))
            info += "• Baseline: IR=\(baselineStr), "
            info += "Confidence=\(confidencePercent)% , "
            info += "Age=\(ageSeconds)s\n"
        } else {
            info += "• No baseline established\n"
        }

        if let context = deviceContext {
            let confidencePercent = String(format: "%.1f", context.confidence * 100)
            info += "• Context: OnBody=\(context.isOnBody), Stable=\(context.isStable), "
            info += "Confidence=\(confidencePercent)%\n"
        } else {
            info += "• No device context\n"
        }

        return info
    }

    // MARK: - Helpers
    private func calculateMovementVariation(_ samples: [SensorData]) -> Double {
        let magnitudes = samples.map { $0.accelerometer.magnitude }
        guard !magnitudes.isEmpty else { return 0 }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        return sqrt(variance)
    }

    private func calculateTemperatureChange(_ samples: [SensorData]) -> Double {
        let temperatures = samples.map { $0.temperature.celsius }
        guard !temperatures.isEmpty else { return 0 }
        return (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
    }

    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
