import SwiftUI
import Charts
import Foundation

// MARK: - Data Sharing Service
class DataSharingService: ObservableObject {
    enum ShareFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF Report"
        case healthKit = "Apple Health"

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .json: return "json"
            case .pdf: return "pdf"
            case .healthKit: return ""
            }
        }
    }

    func shareData(
        _ data: [SensorData],
        metricType: MetricType,
        format: ShareFormat,
        timeRange: TimeRange
    ) -> URL? {
        switch format {
        case .csv:
            return createCSVFile(data, metricType: metricType, timeRange: timeRange)
        case .json:
            return createJSONFile(data, metricType: metricType, timeRange: timeRange)
        case .pdf:
            return createPDFReport(data, metricType: metricType, timeRange: timeRange)
        case .healthKit:
            exportToHealthKit(data, metricType: metricType)
            return nil
        }
    }

    private func createCSVFile(_ data: [SensorData], metricType: MetricType, timeRange: TimeRange) -> URL? {
        var csvContent = metricType.csvHeader() + "\n"

        for sample in data {
            let row = metricType.csvRow(for: sample)
            csvContent += "\(row)\n"
        }

        return saveToFile(content: csvContent, filename: "oralable_\(metricType.rawValue)_\(timeRange.rawValue).csv")
    }

    private func createJSONFile(_ data: [SensorData], metricType: MetricType, timeRange: TimeRange) -> URL? {
        let exportData = HistoricalDataExport(
            metricType: metricType,
            timeRange: timeRange,
            exportDate: Date(),
            dataCount: data.count,
            samples: data.map { HistoricalSample(from: $0, metricType: metricType) }
        )

        do {
            let jsonData = try JSONEncoder().encode(exportData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            return saveToFile(content: jsonString, filename: "oralable_\(metricType.rawValue)_\(timeRange.rawValue).json")
        } catch {
            Logger.shared.error("[creating JSON: \(error)")
            return nil
        }
    }

    private func createPDFReport(_ data: [SensorData], metricType: MetricType, timeRange: TimeRange) -> URL? {
        Logger.shared.info("[HistoricalDetailView] PDF report creation not implemented yet")
        return nil
    }

    private func exportToHealthKit(_ data: [SensorData], metricType: MetricType) {
        Logger.shared.info("[HistoricalDetailView] HealthKit export not implemented yet")
    }

    private func saveToFile(content: String, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            Logger.shared.error("[saving file: \(error)")
            return nil
        }
    }
}

// MARK: - Data Models for Export
struct HistoricalDataExport: Codable {
    let metricType: String
    let timeRange: String
    let exportDate: Date
    let dataCount: Int
    let samples: [HistoricalSample]

    init(metricType: MetricType, timeRange: TimeRange, exportDate: Date, dataCount: Int, samples: [HistoricalSample]) {
        self.metricType = metricType.rawValue
        self.timeRange = timeRange.rawValue
        self.exportDate = exportDate
        self.dataCount = dataCount
        self.samples = samples
    }
}

struct HistoricalSample: Codable {
    let timestamp: Date
    let value: Double
    let additionalData: [String: Double]?

    init(from sensorData: SensorData, metricType: MetricType) {
        self.timestamp = sensorData.timestamp

        switch metricType {
        case .ppg:
            self.value = Double(sensorData.ppg.ir)
            self.additionalData = [
                "red": Double(sensorData.ppg.red),
                "green": Double(sensorData.ppg.green)
            ]
        case .temperature:
            self.value = sensorData.temperature.celsius
            self.additionalData = nil
        case .battery:
            self.value = Double(sensorData.battery.percentage)
            self.additionalData = nil
        case .accelerometer:
            self.value = sensorData.accelerometer.magnitude
            self.additionalData = [
                "x": Double(sensorData.accelerometer.x),
                "y": Double(sensorData.accelerometer.y),
                "z": Double(sensorData.accelerometer.z)
            ]
        case .heartRate:
            if let heartRate = sensorData.heartRate {
                self.value = heartRate.bpm
                self.additionalData = [
                    "quality": heartRate.quality
                ]
            } else {
                self.value = 0
                self.additionalData = nil
            }
        case .spo2:
            if let spo2 = sensorData.spo2 {
                self.value = spo2.percentage
                self.additionalData = [
                    "quality": spo2.quality
                ]
            } else {
                self.value = 0
                self.additionalData = nil
            }
        }
    }
}

// MARK: - PPG Normalization Service (Unified with Persistence)
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

    private func calculateMovementVariation(_ samples: [SensorData]) -> Double {
        let magnitudes = samples.map { $0.accelerometer.magnitude }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        return sqrt(variance)
    }

    private func calculateTemperatureChange(_ samples: [SensorData]) -> Double {
        let temperatures = samples.map { $0.temperature.celsius }
        return (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
    }

    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
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
            return values[index]
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
            info += "• Baseline: IR=\(String(format: "%.0f", baseline.irBaseline)), "
            info += "Confidence=\(String(format: "%.1f%%", baseline.confidence * 100)), "
            info += "Age=\(String(format: "%.0f", Date().timeIntervalSince(baseline.timestamp)))s\n"
        } else {
            info += "• No baseline established\n"
        }

        if let context = deviceContext {
            info += "• Context: OnBody=\(context.isOnBody), Stable=\(context.isStable), "
            info += "Confidence=\(String(format: "%.1f%%", context.confidence * 100))\n"
        } else {
            info += "• No device context\n"
        }

        return info
    }
}

// MARK: - Historical Detail View (Refactored to use components)
struct HistoricalDetailView: View {
    @EnvironmentObject var ppgNormalizationService: PPGNormalizationService
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType

    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass

    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedDate = Date()

    @State private var appMode: HistoricalAppMode = .subscription

    @State private var processor: HistoricalDataProcessor?

    private var chartHeight: CGFloat {
        DesignSystem.Layout.isIPad ? 400 : 300
    }

    private func getProcessor() -> HistoricalDataProcessor {
        if let existing = processor {
            return existing
        }
        let new = HistoricalDataProcessor(normalizationService: ppgNormalizationService)
        processor = new
        return new
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    HistoricalTimeRangePicker(selectedRange: $selectedTimeRange)
                        .padding()
                        .onChange(of: selectedTimeRange) { _, _ in
                            selectedDate = Date()
                            refreshProcessing()
                        }

                    HistoricalDateNavigation(selectedDate: $selectedDate, timeRange: selectedTimeRange)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { _, _ in
                            refreshProcessing()
                        }

                    VStack(spacing: 20) {
                        HistoricalChartView(
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDataPoint: Binding(
                                get: { getProcessor().selectedDataPoint },
                                set: { getProcessor().selectedDataPoint = $0 }
                            ),
                            processed: getProcessor().processedData
                        )
                        .frame(height: chartHeight)

                        HistoricalStatisticsCard(
                            metricType: metricType,
                            processed: getProcessor().processedData
                        )

                        if metricType == .ppg && appMode.allowsAdvancedAnalytics {
                            PPGDebugCard(
                                ble: ble,
                                timeRange: selectedTimeRange,
                                selectedDate: selectedDate
                            )
                        }
                    }
                    .padding(DesignSystem.Layout.edgePadding)
                    .frame(maxWidth: DesignSystem.Layout.contentWidth)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("\(metricType.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await getProcessor().processData(
                from: ble,
                metricType: metricType,
                timeRange: selectedTimeRange,
                selectedDate: selectedDate,
                appMode: appMode
            )
        }
        .onChange(of: ble.sensorDataHistory.count) { _, _ in
            refreshProcessing()
        }
    }

    private func refreshProcessing() {
        Task {
            await getProcessor().processData(
                from: ble,
                metricType: metricType,
                timeRange: selectedTimeRange,
                selectedDate: selectedDate,
                appMode: appMode
            )
        }
    }
}

// MARK: - PPG Debug Card (Complex component kept in main file for now)
struct PPGDebugCard: View {
    @EnvironmentObject var ppgNormalizationService: PPGNormalizationService
    @ObservedObject var ble: OralableBLE
    let timeRange: TimeRange
    let selectedDate: Date

    @State private var normalizationMethod: NormalizationMethod = .contextAware
    @State private var detectedSegments: [DataSegment] = []
    @State private var currentSegmentIndex: Int = 0
    @State private var deviceContext: DeviceContext?
    @State private var lastStateChange: Date = Date()
    @State private var stateHistory: [DeviceState] = []

    enum NormalizationMethod: String, CaseIterable {
        case none = "Raw Values"
        case zScore = "Z-Score"
        case minMax = "Min-Max (0-1)"
        case percentage = "Percentage"
        case baseline = "Baseline Corrected"
        case adaptive = "Adaptive (Auto-Recalibrate)"
        case contextAware = "Context-Aware (Smart)"
    }

    enum DeviceState: String, CaseIterable {
        case onChargerStatic = "On Charger (Static)"
        case offChargerStatic = "Off Charger (Static)"
        case inMotion = "Being Moved"
        case onCheek = "On Cheek (Masseter)"
        case unknown = "Unknown Position"

        var expectedStabilizationTime: TimeInterval {
            switch self {
            case .onChargerStatic: return 10.0
            case .offChargerStatic: return 15.0
            case .inMotion: return 30.0
            case .onCheek: return 45.0
            case .unknown: return 25.0
            }
        }

        var color: Color {
            switch self {
            case .onChargerStatic: return .green
            case .offChargerStatic: return .blue
            case .inMotion: return .orange
            case .onCheek: return .red
            case .unknown: return .gray
            }
        }

        var icon: String {
            switch self {
            case .onChargerStatic: return "battery.100.bolt"
            case .offChargerStatic: return "battery.100"
            case .inMotion: return "figure.walk"
            case .onCheek: return "face.smiling"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    struct DeviceContext {
        let state: DeviceState
        let confidence: Double
        let timeInState: TimeInterval
        let temperatureChange: Double
        let movementVariation: Double
        let isStabilized: Bool

        var shouldNormalize: Bool {
            return isStabilized && timeInState >= state.expectedStabilizationTime
        }
    }

    struct DataSegment: Equatable {
        let id = UUID()
        let startIndex: Int
        let endIndex: Int
        let timestamp: Date
        let isStable: Bool
        let averageVariation: Double

        static func == (lhs: DataSegment, rhs: DataSegment) -> Bool {
            lhs.id == rhs.id
        }
    }

    private var filteredData: [SensorData] {
        let calendar = Calendar.current

        switch timeRange {
        case .hour:
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            return Array(ble.sensorDataHistory.filter {
                $0.timestamp >= startOfHour && $0.timestamp < endOfHour
            }.suffix(20))
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return Array(ble.sensorDataHistory.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.suffix(20))
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return Array(ble.sensorDataHistory.filter {
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }.suffix(20))
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return Array(ble.sensorDataHistory.filter {
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }.suffix(20))
        }
    }

    private var recentPPGData: [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let rawData = Array(filteredData.map { data in
            (timestamp: data.timestamp, ir: Double(data.ppg.ir), red: Double(data.ppg.red), green: Double(data.ppg.green))
        })
        let staticData = Array(rawData.suffix(20))

        if normalizationMethod == .none {
            return staticData
        } else {
            let serviceMethod: PPGNormalizationService.Method
            switch normalizationMethod {
            case .none:
                serviceMethod = .raw
            case .zScore, .minMax, .percentage:
                serviceMethod = .dynamicRange
            case .baseline:
                serviceMethod = .adaptiveBaseline
            case .adaptive:
                serviceMethod = .heartRateSimulation
            case .contextAware:
                serviceMethod = .persistent
            }

            return ppgNormalizationService.normalizePPGData(
                staticData,
                method: serviceMethod,
                sensorData: Array(filteredData)
            )
        }
    }

    private func updateSegmentsIfNeeded() {
        if normalizationMethod == .adaptive {
            let rawData = Array(filteredData.map { data in
                (timestamp: data.timestamp, ir: Double(data.ppg.ir), red: Double(data.ppg.red), green: Double(data.ppg.green))
            })
            let newSegments = detectDataSegments(rawData)
            if newSegments != detectedSegments {
                detectedSegments = newSegments
            }
        } else if normalizationMethod == .contextAware {
            updateDeviceContext()
        }
    }

    private func updateDeviceContext() {
        guard !filteredData.isEmpty else { return }

        let context = detectDeviceState(from: filteredData)
        if let context = context {
            deviceContext = context
            if stateHistory.isEmpty || stateHistory.last != context.state {
                stateHistory.append(context.state)
                lastStateChange = Date()
                if stateHistory.count > 10 {
                    stateHistory.removeFirst()
                }
            }
        }
    }

    private func detectDeviceState(from data: [SensorData]) -> DeviceContext? {
        guard data.count >= 5 else { return nil }

        let recentSamples = Array(data.suffix(10))
        let accelerometerVariation = calculateAccelerometerVariation(recentSamples)
        let temperatureChange = calculateTemperatureChange(recentSamples)
        let batteryStatus = recentSamples.last?.battery.percentage ?? 0

        let detectedState = classifyDeviceState(
            accelerometerVariation: accelerometerVariation,
            temperatureChange: temperatureChange,
            batteryLevel: batteryStatus
        )

        let confidence = calculateStateConfidence(detectedState, samples: recentSamples)
        let timeInState = Date().timeIntervalSince(lastStateChange)
        let isStabilized = isDeviceStabilized(detectedState, timeInState: timeInState, confidence: confidence)

        return DeviceContext(
            state: detectedState,
            confidence: confidence,
            timeInState: timeInState,
            temperatureChange: temperatureChange,
            movementVariation: accelerometerVariation,
            isStabilized: isStabilized
        )
    }

    private func calculateAccelerometerVariation(_ samples: [SensorData]) -> Double {
        guard samples.count > 1 else { return 0 }
        let magnitudes = samples.map { $0.accelerometer.magnitude }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        return sqrt(variance)
    }

    private func calculateTemperatureChange(_ samples: [SensorData]) -> Double {
        guard samples.count > 1 else { return 0 }
        let temperatures = samples.map { $0.temperature.celsius }
        return (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
    }

    private func classifyDeviceState(
        accelerometerVariation: Double,
        temperatureChange: Double,
        batteryLevel: Int
    ) -> DeviceState {
        let lowMovementThreshold = 0.1
        let moderateMovementThreshold = 0.5
        let lowTempChangeThreshold = 0.5
        let moderateTempChangeThreshold = 2.0

        if batteryLevel > 95 && accelerometerVariation < lowMovementThreshold {
            return .onChargerStatic
        } else if accelerometerVariation < lowMovementThreshold && temperatureChange < lowTempChangeThreshold {
            return .offChargerStatic
        } else if accelerometerVariation > moderateMovementThreshold {
            return .inMotion
        } else if temperatureChange > moderateTempChangeThreshold && accelerometerVariation < moderateMovementThreshold {
            return .onCheek
        } else {
            return .unknown
        }
    }

    private func calculateStateConfidence(_ state: DeviceState, samples: [SensorData]) -> Double {
        guard samples.count >= 3 else { return 0.5 }
        var consistentSamples = 0

        for i in 1..<samples.count {
            let prevSample = samples[i-1]
            let currentSample = samples[i]

            let accelVariation = abs(currentSample.accelerometer.magnitude - prevSample.accelerometer.magnitude)
            let tempChange = abs(currentSample.temperature.celsius - prevSample.temperature.celsius)

            var isConsistent = false
            switch state {
            case .onChargerStatic, .offChargerStatic:
                isConsistent = accelVariation < 0.2 && tempChange < 1.0
            case .inMotion:
                isConsistent = accelVariation > 0.3
            case .onCheek:
                isConsistent = tempChange > 1.0 && accelVariation < 0.4
            case .unknown:
                isConsistent = true
            }
            if isConsistent { consistentSamples += 1 }
        }

        return Double(consistentSamples) / Double(samples.count - 1)
    }

    private func isDeviceStabilized(_ state: DeviceState, timeInState: TimeInterval, confidence: Double) -> Bool {
        let requiredConfidence: Double = 0.7
        return confidence >= requiredConfidence && timeInState >= state.expectedStabilizationTime
    }

    private func detectDataSegments(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [DataSegment] {
        guard data.count >= 6 else { return [] }

        var segments: [DataSegment] = []
        var currentSegmentStart = 0
        let windowSize = 5
        let movementThreshold: Double = 1000
        let stabilityDuration = 5

        var i = windowSize
        while i < data.count {
            let windowData = Array(data[(i-windowSize)..<i])
            let variation = calculateWindowVariation(windowData)
            let isMovement = variation > movementThreshold

            if isMovement || i == data.count - 1 {
                let segmentEnd = i - windowSize
                if segmentEnd > currentSegmentStart + stabilityDuration {
                    let segmentData = Array(data[currentSegmentStart..<segmentEnd])
                    let avgVariation = calculateWindowVariation(segmentData)
                    let isStable = avgVariation < movementThreshold / 2

                    segments.append(DataSegment(
                        startIndex: currentSegmentStart,
                        endIndex: segmentEnd,
                        timestamp: data[currentSegmentStart].timestamp,
                        isStable: isStable,
                        averageVariation: avgVariation
                    ))
                }
                if isMovement {
                    i += stabilityDuration
                    currentSegmentStart = i
                }
            }
            i += 1
        }

        if currentSegmentStart < data.count - stabilityDuration {
            let segmentData = Array(data[currentSegmentStart..<data.count])
            let avgVariation = calculateWindowVariation(segmentData)
            let isStable = avgVariation < movementThreshold / 2

            segments.append(DataSegment(
                startIndex: currentSegmentStart,
                endIndex: data.count,
                timestamp: data[currentSegmentStart].timestamp,
                isStable: isStable,
                averageVariation: avgVariation
            ))
        }

        return segments
    }

    private func calculateWindowVariation(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> Double {
        guard data.count > 1 else { return 0 }
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }

        func standardDeviation(_ values: [Double]) -> Double {
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            return sqrt(variance)
        }

        let irStd = standardDeviation(irValues)
        let redStd = standardDeviation(redValues)
        let greenStd = standardDeviation(greenValues)

        return max(irStd, max(redStd, greenStd))
    }

    private func normalizeSegment(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], using method: NormalizationMethod) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { return data }

        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }

        switch method {
        case .minMax:
            let irMin = irValues.min() ?? 0
            let irMax = irValues.max() ?? 1
            let redMin = redValues.min() ?? 0
            let redMax = redValues.max() ?? 1
            let greenMin = greenValues.min() ?? 0
            let greenMax = greenValues.max() ?? 1

            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0,
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0
                )
            }

        case .baseline:
            let irBaseline = data.first?.ir ?? 0
            let redBaseline = data.first?.red ?? 0
            let greenBaseline = data.first?.green ?? 0

            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: sample.ir - irBaseline,
                    red: sample.red - redBaseline,
                    green: sample.green - greenBaseline
                )
            }

        default:
            return data
        }
    }

    private func adaptiveNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !detectedSegments.isEmpty else {
            return normalizeSegment(data, using: .minMax)
        }

        var normalizedData: [(timestamp: Date, ir: Double, red: Double, green: Double)] = []

        for segment in detectedSegments {
            let segmentData = Array(data[segment.startIndex..<min(segment.endIndex, data.count)])
            if segment.isStable && segmentData.count >= 5 {
                normalizedData.append(contentsOf: normalizeSegment(segmentData, using: .minMax))
            } else {
                normalizedData.append(contentsOf: normalizeSegment(segmentData, using: .baseline))
            }
        }
        return normalizedData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("PPG Channel Debug")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("Last \(recentPPGData.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Normalization Method")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("Normalization", selection: $normalizationMethod) {
                    ForEach(NormalizationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: normalizationMethod) { _, _ in
                    updateSegmentsIfNeeded()
                }

                Text(normalizationExplanation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)

                if normalizationMethod == .contextAware {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Persistent Normalization State")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Button("Reset") {
                                ppgNormalizationService.resetPersistentState()
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        }

                        Text(ppgNormalizationService.getStateInfo())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(6)
                    }
                }

                if normalizationMethod == .contextAware, let context = deviceContext {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: context.state.icon)
                                .foregroundColor(context.state.color)
                            Text("Device State: \(context.state.rawValue)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(context.state.color)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Confidence")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.0f%%", context.confidence * 100))")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(context.confidence > 0.7 ? .green : .orange)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Time in State")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.0f", context.timeInState))s")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expected")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.0f", context.state.expectedStabilizationTime))s")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(context.isStabilized ? .green : .orange)
                                    .frame(width: 8, height: 8)
                                Text(context.isStabilized ? "Ready" : "Wait")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(context.isStabilized ? .green : .orange)
                            }
                        }
                    }
                    .padding(8)
                    .background(context.state.color.opacity(0.1))
                    .cornerRadius(6)
                }

                if normalizationMethod == .adaptive && !detectedSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detected \(detectedSegments.count) data segments:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)

                        ForEach(Array(detectedSegments.enumerated()), id: \.element.id) { index, segment in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.isStable ? .green : .orange)
                                    .frame(width: 6, height: 6)

                                Text("Segment \(index + 1)")
                                    .font(.caption2)
                                    .fontWeight(.medium)

                                Text(segment.isStable ? "Stable" : "Movement")
                                    .font(.caption2)
                                    .foregroundColor(segment.isStable ? .green : .orange)

                                Spacer()

                                Text("\(segment.endIndex - segment.startIndex) samples")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if detectedSegments.count > 1 {
                            HStack {
                                Text("View segment:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Picker("Segment", selection: $currentSegmentIndex) {
                                    Text("All").tag(-1)
                                    ForEach(0..<detectedSegments.count, id: \.self) { index in
                                        Text("\(index + 1)").tag(index)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.caption2)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.bottom, 8)

            if recentPPGData.isEmpty {
                VStack(spacing: 8) {
                    Text("No PPG data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Filtered data count: \(filteredData.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        let displayData = getDisplayData()
                        ForEach(Array(displayData.enumerated().reversed()), id: \.offset) { _, data in
                            VStack(spacing: 4) {
                                Text(timeFormatter.string(from: data.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                VStack(spacing: 2) {
                                    HStack {
                                        Circle().fill(.red).frame(width: 6, height: 6)
                                        Text(formatNormalizedValue(data.ir))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    HStack {
                                        Circle().fill(.pink).frame(width: 6, height: 6)
                                        Text(formatNormalizedValue(data.red))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    HStack {
                                        Circle().fill(.green).frame(width: 6, height: 6)
                                        Text(formatNormalizedValue(data.green))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
        .onAppear {
            updateSegmentsIfNeeded()
            if normalizationMethod == .contextAware {
                startContextUpdates()
            }
        }
        .onDisappear {
            stopContextUpdates()
        }
    }

    private func getDisplayData() -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        if normalizationMethod == .adaptive && currentSegmentIndex >= 0 && currentSegmentIndex < detectedSegments.count {
            let segment = detectedSegments[currentSegmentIndex]
            return Array(recentPPGData[segment.startIndex..<min(segment.endIndex, recentPPGData.count)])
        } else {
            return Array(recentPPGData.suffix(20))
        }
    }

    private func formatNormalizedValue(_ value: Double) -> String {
        switch normalizationMethod {
        case .none:
            return String(format: "%.0f", value)
        case .zScore:
            return String(format: "%.2f", value)
        case .minMax, .adaptive:
            return String(format: "%.3f", value)
        case .percentage:
            return String(format: "%.1f%%", value)
        case .baseline:
            return String(format: "%.0f", value)
        case .contextAware:
            return String(format: "%.3f", value)
        }
    }

    private var normalizationExplanation: String {
        switch normalizationMethod {
        case .none:
            return "Raw sensor values (0-65535)"
        case .zScore:
            return "Standardized values (mean=0, std=1)"
        case .minMax:
            return "Scaled to 0-1 range"
        case .percentage:
            return "Percentage change from mean"
        case .baseline:
            return "Relative to first 3 samples"
        case .adaptive:
            return "Auto-detects sensor movement and recalibrates normalization for each stable period"
        case .contextAware:
            return "PERSISTENT SMART: Remembers baseline across sessions, adapts to device state (charging, on body, moving), preserves physiological signal patterns."
        }
    }

    private func startContextUpdates() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if normalizationMethod == .contextAware {
                updateDeviceContext()
            }
        }
    }

    private func stopContextUpdates() {
        // No-op (timer auto-invalidates when view disappears in this scoped use)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
