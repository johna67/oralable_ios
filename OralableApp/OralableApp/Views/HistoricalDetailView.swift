import SwiftUI
import SwiftUI
import Charts
import Foundation

// MARK: - MetricType Definition (if not defined elsewhere)
enum MetricType: String, CaseIterable {
    case battery = "battery"
    case ppg = "ppg"
    case heartRate = "heartRate"
    case spo2 = "spo2"
    case temperature = "temperature"
    case accelerometer = "accelerometer"
    
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .ppg: return "PPG Signals"
        case .heartRate: return "Heart Rate"
        case .spo2: return "Blood Oxygen"
        case .temperature: return "Temperature"
        case .accelerometer: return "Accelerometer"
        }
    }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .ppg: return "waveform.path.ecg"
        case .heartRate: return "heart.fill"
        case .spo2: return "drop.fill"
        case .temperature: return "thermometer"
        case .accelerometer: return "gyroscope"
        }
    }
    
    var color: Color {
        switch self {
        case .battery: return .green
        case .ppg: return .red
        case .heartRate: return .pink
        case .spo2: return .blue
        case .temperature: return .orange
        case .accelerometer: return .purple
        }
    }
    
    func csvHeader() -> String {
        switch self {
        case .battery:
            return "Timestamp,Battery_Percentage"
        case .ppg:
            return "Timestamp,PPG_Red,PPG_IR,PPG_Green"
        case .heartRate:
            return "Timestamp,Heart_Rate_BPM,Quality"
        case .spo2:
            return "Timestamp,SpO2_Percentage,Quality"
        case .temperature:
            return "Timestamp,Temperature_Celsius"
        case .accelerometer:
            return "Timestamp,Accel_X,Accel_Y,Accel_Z,Magnitude"
        }
    }
    
    func csvRow(for data: SensorData) -> String {
        let timestamp = ISO8601DateFormatter().string(from: data.timestamp)
        switch self {
        case .battery:
            return "\(timestamp),\(data.battery.percentage)"
        case .ppg:
            return "\(timestamp),\(data.ppg.red),\(data.ppg.ir),\(data.ppg.green)"
        case .heartRate:
            if let hr = data.heartRate {
                return "\(timestamp),\(hr.bpm),\(hr.quality)"
            } else {
                return "\(timestamp),0,0"
            }
        case .spo2:
            if let spo2 = data.spo2 {
                return "\(timestamp),\(spo2.percentage),\(spo2.quality)"
            } else {
                return "\(timestamp),0,0"
            }
        case .temperature:
            return "\(timestamp),\(data.temperature.celsius)"
        case .accelerometer:
            return "\(timestamp),\(data.accelerometer.x),\(data.accelerometer.y),\(data.accelerometer.z),\(data.accelerometer.magnitude)"
        }
    }
}

// MARK: - App Mode and Subscription Management
enum AppMode: String, CaseIterable {
    case viewer = "Viewer"
    case subscription = "Subscription"
    
    var description: String {
        switch self {
        case .viewer:
            return "View historical data with basic analysis"
        case .subscription:
            return "Full access with advanced analytics and sharing"
        }
    }
    
    var allowsDataSharing: Bool {
        return self == .subscription
    }
    
    var allowsAdvancedAnalytics: Bool {
        return self == .subscription
    }
}

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
            case .healthKit: return "" // No file for HealthKit
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
            print("Error creating JSON: \(error)")
            return nil
        }
    }
    
    private func createPDFReport(_ data: [SensorData], metricType: MetricType, timeRange: TimeRange) -> URL? {
        // PDF creation would require a proper PDF library or UIKit/AppKit integration
        // For now, return nil - this would be implemented with PDFKit
        print("PDF report creation not implemented yet")
        return nil
    }
    
    private func exportToHealthKit(_ data: [SensorData], metricType: MetricType) {
        // HealthKit export would require HealthKit framework
        print("HealthKit export not implemented yet")
    }
    
    private func saveToFile(content: String, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving file: \(error)")
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

// MARK: - Centralized Data Processing Manager
@MainActor
class HistoricalDataProcessor: ObservableObject {
    @Published var processedData: ProcessedHistoricalData?
    @Published var isProcessing = false
    @Published var selectedDataPoint: SensorData?
    
    private let normalizationService = PPGNormalizationService.shared
    private var cachedData: [String: ProcessedHistoricalData] = [:]
    
    struct ProcessedHistoricalData {
        let rawData: [SensorData]
        let normalizedData: [(timestamp: Date, value: Double)]
        let statistics: DataStatistics
        let segments: [DataSegment]
        let deviceContext: DeviceContext?
        let cacheKey: String
        let processingMethod: String
    }
    
    struct DataStatistics {
        let average: Double
        let minimum: Double
        let maximum: Double
        let standardDeviation: Double
        let variationCoefficient: Double
        let sampleCount: Int
    }
    
    struct DataSegment {
        let startIndex: Int
        let endIndex: Int
        let isStable: Bool
        let confidence: Double
        let timestamp: Date
    }
    
    struct DeviceContext {
        let state: PPGDebugCard.DeviceState
        let confidence: Double
        let isStabilized: Bool
        let timeInState: TimeInterval
    }
    
    func processData(
        from ble: OralableBLE,
        metricType: MetricType,
        timeRange: TimeRange,
        selectedDate: Date,
        appMode: AppMode
    ) async {
        // Create normalized cache key based on the actual time period
        let calendar = Calendar.current
        let normalizedDate: Date
        
        switch timeRange {
        case .hour:
            normalizedDate = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
        case .day:
            normalizedDate = calendar.startOfDay(for: selectedDate)
        case .week:
            normalizedDate = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        case .month:
            normalizedDate = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        }
        
        let cacheKey = "\(metricType.rawValue)_\(timeRange.rawValue)_\(Int(normalizedDate.timeIntervalSince1970))"
        
        // DEBUG: Log what we're trying to process
        print("🔄 Processing historical data:")
        print("   Metric: \(metricType.title)")
        print("   Time Range: \(timeRange.rawValue)")
        print("   Selected Date: \(selectedDate)")
        print("   Normalized Date: \(normalizedDate)")
        print("   Cache Key: \(cacheKey)")
        print("   Total sensor history count: \(ble.sensorDataHistory.count)")
        
        if let cached = cachedData[cacheKey] {
            print("✅ Using cached data")
            self.processedData = cached
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let filteredData = filterData(from: ble.sensorDataHistory, timeRange: timeRange, selectedDate: selectedDate)
        
        guard !filteredData.isEmpty else {
            print("❌ No data after filtering")
            processedData = nil
            return
        }
        
        print("📊 Processing \(filteredData.count) filtered readings")
        
        let normalizedData = await processMetricData(filteredData, metricType: metricType, appMode: appMode)
        let statistics = calculateStatistics(from: normalizedData)
        let segments = appMode.allowsAdvancedAnalytics ? detectDataSegments(filteredData) : []
        let deviceContext = appMode.allowsAdvancedAnalytics ? analyzeDeviceContext(filteredData) : nil
        
        let processed = ProcessedHistoricalData(
            rawData: filteredData,
            normalizedData: normalizedData,
            statistics: statistics,
            segments: segments,
            deviceContext: deviceContext,
            cacheKey: cacheKey,
            processingMethod: appMode.allowsAdvancedAnalytics ? "Advanced" : "Basic"
        )
        
        cachedData[cacheKey] = processed
        
        if cachedData.count > 20 {
            let oldestKey = cachedData.keys.sorted().first!
            cachedData.removeValue(forKey: oldestKey)
        }
        
        print("✅ Processed data successfully - \(statistics.sampleCount) samples")
        
        self.processedData = processed
    }
    
    private func filterData(from data: [SensorData], timeRange: TimeRange, selectedDate: Date) -> [SensorData] {
        let calendar = Calendar.current
        
        // DEBUG: Log data availability
        print("📊 Filtering \(data.count) total sensor readings")
        if let earliest = data.first?.timestamp, let latest = data.last?.timestamp {
            print("📅 Data range: \(earliest) to \(latest)")
        }
        
        var filtered: [SensorData] = []
        
        switch timeRange {
        case .hour:
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            print("⏰ Hour filter: \(startOfHour) to \(endOfHour)")
            filtered = data.filter { $0.timestamp >= startOfHour && $0.timestamp < endOfHour }
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            print("📅 Day filter: \(startOfDay) to \(endOfDay)")
            filtered = data.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            print("📅 Week filter: \(startOfWeek) to \(endOfWeek)")
            filtered = data.filter { $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek }
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            print("📅 Month filter: \(startOfMonth) to \(endOfMonth)")
            filtered = data.filter { $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth }
        }
        
        print("✅ Filtered to \(filtered.count) readings for selected period")
        
        // REMOVED: Automatic fallback to all data
        // Let the UI show "No data" message instead of confusing users
        // by showing the same recent data for all historical periods
        
        if filtered.isEmpty {
            print("⚠️ No data found for selected period")
        }
        
        return filtered
    }
    
    private func processMetricData(_ data: [SensorData], metricType: MetricType, appMode: AppMode) async -> [(timestamp: Date, value: Double)] {
        switch metricType {
        case .ppg:
            if appMode.allowsAdvancedAnalytics {
                let rawPPG = data.map { (timestamp: $0.timestamp, ir: Double($0.ppg.ir), red: Double($0.ppg.red), green: Double($0.ppg.green)) }
                let normalized = normalizationService.normalizePPGData(rawPPG, method: .persistent, sensorData: data)
                return normalized.map { (timestamp: $0.timestamp, value: $0.ir) }
            } else {
                return data.map { (timestamp: $0.timestamp, value: Double($0.ppg.ir)) }
            }
        case .temperature:
            return data.map { (timestamp: $0.timestamp, value: $0.temperature.celsius) }
        case .battery:
            return data.map { (timestamp: $0.timestamp, value: Double($0.battery.percentage)) }
        case .accelerometer:
            return data.map { (timestamp: $0.timestamp, value: $0.accelerometer.magnitude) }
        case .heartRate:
            return data.compactMap { sensorData in
                guard let heartRate = sensorData.heartRate else { return nil }
                return (timestamp: sensorData.timestamp, value: heartRate.bpm)
            }
        case .spo2:
            return data.compactMap { sensorData in
                guard let spo2 = sensorData.spo2 else { return nil }
                return (timestamp: sensorData.timestamp, value: spo2.percentage)
            }
        }
    }
    
    private func calculateStatistics(from data: [(timestamp: Date, value: Double)]) -> DataStatistics {
        let values = data.map { $0.value }
        guard !values.isEmpty else {
            return DataStatistics(average: 0, minimum: 0, maximum: 0, standardDeviation: 0, variationCoefficient: 0, sampleCount: 0)
        }
        
        let average = values.reduce(0, +) / Double(values.count)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 0
        
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        let variationCoefficient = average != 0 ? (standardDeviation / abs(average)) * 100 : 0
        
        return DataStatistics(
            average: average,
            minimum: minimum,
            maximum: maximum,
            standardDeviation: standardDeviation,
            variationCoefficient: variationCoefficient,
            sampleCount: values.count
        )
    }
    
    private func detectDataSegments(_ data: [SensorData]) -> [DataSegment] {
        var segments: [DataSegment] = []
        let windowSize = 5
        
        guard data.count > windowSize * 2 else { return [] }
        
        var currentStart = 0
        for i in windowSize..<(data.count - windowSize) {
            let window = Array(data[(i-windowSize)..<(i+windowSize)])
            let variation = calculateWindowVariation(window)
            
            if variation > 0.5 {
                if i - currentStart > windowSize {
                    segments.append(DataSegment(
                        startIndex: currentStart,
                        endIndex: i,
                        isStable: true,
                        confidence: 0.8,
                        timestamp: data[currentStart].timestamp
                    ))
                }
                currentStart = i + windowSize
            }
        }
        
        if currentStart < data.count - windowSize {
            segments.append(DataSegment(
                startIndex: currentStart,
                endIndex: data.count,
                isStable: true,
                confidence: 0.8,
                timestamp: data[currentStart].timestamp
            ))
        }
        
        return segments
    }
    
    private func calculateWindowVariation(_ data: [SensorData]) -> Double {
        let magnitudes = data.map { $0.accelerometer.magnitude }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        return sqrt(variance)
    }
    
    private func analyzeDeviceContext(_ data: [SensorData]) -> DeviceContext? {
        guard data.count >= 5 else { return nil }
        
        let recent = Array(data.suffix(10))
        let movementVariation = calculateWindowVariation(recent)
        let tempChange = (recent.map { $0.temperature.celsius }.max() ?? 0) - (recent.map { $0.temperature.celsius }.min() ?? 0)
        let batteryLevel = recent.last?.battery.percentage ?? 0
        
        let state: PPGDebugCard.DeviceState
        if batteryLevel > 95 && movementVariation < 0.1 {
            state = .onChargerStatic
        } else if movementVariation < 0.1 && tempChange < 0.5 {
            state = .offChargerStatic
        } else if movementVariation > 0.5 {
            state = .inMotion
        } else if tempChange > 2.0 {
            state = .onCheek
        } else {
            state = .unknown
        }
        
        let confidence = min(1.0, max(0.0, 1.0 - (movementVariation / 2.0)))
        let isStabilized = movementVariation < 0.2 && confidence > 0.7
        
        return DeviceContext(
            state: state,
            confidence: confidence,
            isStabilized: isStabilized,
            timeInState: 60.0
        )
    }
    
    func clearCache() {
        cachedData.removeAll()
    }
}

// MARK: - Time Range Picker
struct TimeRangePicker: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        HStack(spacing: 30) {
            ForEach([TimeRange.day, TimeRange.week, TimeRange.month], id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.rawValue)
                        .font(.system(size: 17, weight: selectedRange == range ? .semibold : .regular))
                        .foregroundColor(selectedRange == range ? .blue : .primary)
                }
            }
        }
        .padding(.horizontal)
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

// MARK: - Historical Detail View (Unified with Processor)
struct HistoricalDetailView: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedDate = Date()
    
    // Inject or derive app mode; default to subscription for now
    @State private var appMode: AppMode = .subscription
    
    @StateObject private var processor = HistoricalDataProcessor()
    
    private var chartHeight: CGFloat {
        DesignSystem.Layout.isIPad ? 400 : 300
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    TimeRangePicker(selectedRange: $selectedTimeRange)
                        .padding()
                        .onChange(of: selectedTimeRange) { _, _ in
                            selectedDate = Date()
                            refreshProcessing()
                        }
                    
                    DateNavigationView(selectedDate: $selectedDate, timeRange: selectedTimeRange)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { _, _ in
                            refreshProcessing()
                        }
                    
                    VStack(spacing: 20) {
                        EnhancedHistoricalChartCardUnified(
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDataPoint: $processor.selectedDataPoint,
                            processed: processor.processedData
                        )
                        .frame(height: chartHeight)
                        
                        EnhancedStatisticsCardUnified(
                            metricType: metricType,
                            processed: processor.processedData
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
                    .frame(maxWidth: DesignSystem.Layout.contentWidth(for: geometry))
                    .frame(maxWidth: .infinity) // Center the content
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
            await processor.processData(
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
            await processor.processData(
                from: ble,
                metricType: metricType,
                timeRange: selectedTimeRange,
                selectedDate: selectedDate,
                appMode: appMode
            )
        }
    }
}

// MARK: - Date Navigation View (Enhanced for all time ranges)
struct DateNavigationView: View {
    @Binding var selectedDate: Date
    let timeRange: TimeRange
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        switch timeRange {
        case .hour:
            formatter.dateFormat = "HH:mm, dd MMM"
        case .day:
            formatter.dateFormat = "EEEE, dd MMMM"
        case .week:
            formatter.dateFormat = "dd MMM yyyy"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter
    }
    
    private var displayText: String {
        switch timeRange {
        case .hour:
            return "Hour View"
        case .day:
            return dateFormatter.string(from: selectedDate)
        case .week:
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
                let startFormatter = DateFormatter()
                startFormatter.dateFormat = "dd MMM"
                let endFormatter = DateFormatter()
                endFormatter.dateFormat = "dd MMM yyyy"
                return "\(startFormatter.string(from: weekInterval.start)) - \(endFormatter.string(from: endDate))"
            }
            return "This Week"
        case .month:
            return dateFormatter.string(from: selectedDate)
        }
    }
    
    private func navigateBackward() {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            selectedDate = calendar.date(byAdding: .hour, value: -1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func navigateForward() {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            selectedDate = calendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
    }
    
    private var canNavigateForward: Bool {
        let calendar = Calendar.current
        let today = Date()
        
        switch timeRange {
        case .hour:
            let currentHourStart = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let thisHourStart = calendar.dateInterval(of: .hour, for: today)?.start ?? today
            return currentHourStart < thisHourStart
        case .day:
            return !calendar.isDate(selectedDate, inSameDayAs: today)
        case .week:
            let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            return currentWeekStart < thisWeekStart
        case .month:
            let currentMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let thisMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            return currentMonth < thisMonth
        }
    }
    
    var body: some View {
        HStack {
            Button(action: navigateBackward) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack {
                Text(displayText)
                    .font(.headline)
                    .fontWeight(.medium)
                
                if timeRange != .day {
                    Text(periodInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: navigateForward) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(canNavigateForward ? .blue : .gray)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(!canNavigateForward)
        }
        .padding(.vertical, 8)
    }
    
    private var periodInfo: String {
        let calendar = Calendar.current
        switch timeRange {
        case .hour:
            guard let interval = calendar.dateInterval(of: .hour, for: selectedDate) else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let endTime = calendar.date(byAdding: .minute, value: -1, to: interval.end) ?? interval.end
            return "\(formatter.string(from: interval.start)) - \(formatter.string(from: endTime))"
        case .day:
            return ""
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return "" }
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: interval.start)) - \(formatter.string(from: end))"
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else { return "" }
            let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 0
            return "\(daysInMonth) days"
        }
    }
}

// MARK: - Unified Enhanced Chart (consumes processor output)
struct EnhancedHistoricalChartCardUnified: View {
    let metricType: MetricType
    let timeRange: TimeRange
    @Binding var selectedDataPoint: SensorData?
    let processed: HistoricalDataProcessor.ProcessedHistoricalData?
    
    // X-axis domain - the full time range regardless of data points
    private var xAxisDomain: ClosedRange<Date> {
        guard let processed = processed, !processed.rawData.isEmpty else {
            // Default to "now" if no data
            let now = Date()
            return now.addingTimeInterval(-3600)...now
        }
        
        let calendar = Calendar.current
        let referenceDate = processed.rawData.first?.timestamp ?? Date()
        
        switch timeRange {
        case .hour:
            if let hourInterval = calendar.dateInterval(of: .hour, for: referenceDate) {
                return hourInterval.start...hourInterval.end
            }
        case .day:
            let startOfDay = calendar.startOfDay(for: referenceDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return startOfDay...endOfDay
        case .week:
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) {
                return weekInterval.start...weekInterval.end
            }
        case .month:
            if let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) {
                return monthInterval.start...monthInterval.end
            }
        }
        
        // Fallback
        return referenceDate...referenceDate.addingTimeInterval(3600)
    }
    
    // X-axis stride based on time range
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .hour:
            return .minute // Show every 10 minutes
        case .day:
            return .hour   // Show every few hours
        case .week:
            return .day    // Show every day
        case .month:
            return .day    // Show every few days
        }
    }
    
    // X-axis date format based on time range
    private var xAxisDateFormat: Date.FormatStyle {
        switch timeRange {
        case .hour:
            return .dateTime.hour().minute()  // "14:30"
        case .day:
            return .dateTime.hour()          // "14"
        case .week:
            return .dateTime.weekday(.abbreviated).day()  // "Mon 5"
        case .month:
            return .dateTime.month(.abbreviated).day()    // "Nov 5"
        }
    }
    
    private var chartPoints: [(timestamp: Date, value: Double)] {
        guard let processed = processed else { return [] }
        if metricType == .ppg {
            return processed.normalizedData
        } else {
            // For non-PPG, normalizedData already carries mapped values
            return processed.normalizedData
        }
    }
    
    private var emptyStateMessage: String {
        "No data available for the selected period"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metricType.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let processed {
                        Text("\(processed.statistics.sampleCount) samples • \(processed.processingMethod) processing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                }
                Spacer()
            }
            
            if chartPoints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(emptyStateMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(Array(chartPoints.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value(metricType.title, point.value)
                        )
                        .foregroundStyle(metricType == .ppg ? .blue : metricType.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value(metricType.title, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [(metricType == .ppg ? Color.blue : metricType.color).opacity(0.1),
                                         (metricType == .ppg ? Color.blue : metricType.color).opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    if let selected = selectedDataPoint {
                        if let closest = closestPoint(to: selected.timestamp) {
                            PointMark(
                                x: .value("Time", closest.timestamp),
                                y: .value(metricType.title, closest.value)
                            )
                            .foregroundStyle(metricType == .ppg ? .blue : metricType.color)
                            .symbol(.circle)
                            .symbolSize(80)
                            
                            RuleMark(x: .value("Time", closest.timestamp))
                                .foregroundStyle(.gray.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1))
                        }
                    }
                }
                .frame(height: 250)
                .chartXScale(domain: xAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel(format: xAxisDateFormat)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.0f", doubleValue))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            if let selected = selectedDataPoint, let processed {
                TooltipOverlayUnified(
                    metricType: metricType,
                    selected: selected,
                    processed: processed
                )
            }
            
            Text("Context is key to getting a better understanding of your \(metricType.title).")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
    
    private func closestPoint(to time: Date) -> (timestamp: Date, value: Double)? {
        guard !chartPoints.isEmpty else { return nil }
        return chartPoints.min(by: { abs($0.timestamp.timeIntervalSince(time)) < abs($1.timestamp.timeIntervalSince(time)) })
    }
}

// MARK: - Tooltip Overlay (Unified with processor output)
struct TooltipOverlayUnified: View {
    let metricType: MetricType
    let selected: SensorData
    let processed: HistoricalDataProcessor.ProcessedHistoricalData
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
    
    private var valueText: String {
        // Find nearest normalized/mapped value to selected timestamp
        let nearest = processed.normalizedData.min(by: { abs($0.timestamp.timeIntervalSince(selected.timestamp)) < abs($1.timestamp.timeIntervalSince(selected.timestamp)) })
        let value = nearest?.value ?? 0
        
        switch metricType {
        case .ppg:
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f°C", value)
        case .battery:
            return String(format: "%.0f%%", value)
        case .accelerometer:
            return String(format: "%.2f", value)
        case .heartRate:
            return String(format: "%.0f BPM", value)
        case .spo2:
            return String(format: "%.0f%%", value)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(timeFormatter.string(from: selected.timestamp))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: metricType.icon)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            Text(valueText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(metricType.color)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            Path { path in
                let arrowWidth: CGFloat = 8
                let arrowHeight: CGFloat = 4
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: arrowWidth/2, y: arrowHeight))
                path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                path.closeSubpath()
            }
            .fill(metricType.color)
            .offset(y: 6)
            .frame(width: 8, height: 4),
            alignment: .bottom
        )
    }
}

// MARK: - Enhanced Statistics Card (Unified with processor)
struct EnhancedStatisticsCardUnified: View {
    let metricType: MetricType
    let processed: HistoricalDataProcessor.ProcessedHistoricalData?
    
    private func formatValue(_ value: Double) -> String {
        switch metricType {
        case .ppg:
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f°C", value)
        case .battery:
            return String(format: "%.0f%%", value)
        case .accelerometer:
            return String(format: "%.2f", value)
        case .heartRate:
            return String(format: "%.0f BPM", value)
        case .spo2:
            return String(format: "%.0f%%", value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let stats = processed?.statistics, stats.sampleCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatValue(stats.average))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(metricType.color)
                }
                
                Divider()
                
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minimum")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(stats.minimum))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maximum")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatValue(stats.maximum))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Std Dev")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatValue(stats.standardDeviation))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coeff. Variation")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f%%", stats.variationCoefficient))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text("\(stats.sampleCount) pts")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No statistics available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }
}

// MARK: - PPG Debug Card (kept, no temp test UI)
struct PPGDebugCard: View {
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
            
            return PPGNormalizationService.shared.normalizePPGData(
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
                                PPGNormalizationService.shared.resetPersistentState()
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        }
                        
                        Text(PPGNormalizationService.shared.getStateInfo())
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
