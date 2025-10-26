import SwiftUI
import Charts
import Foundation

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
        let formatter = ISO8601DateFormatter()
        var csvContent = "Timestamp,\(metricType.csvHeaders)\n"
        
        for sample in data {
            let timestamp = formatter.string(from: sample.timestamp)
            let values = metricType.csvValues(from: sample)
            csvContent += "\(timestamp),\(values)\n"
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
    let metricTypeRawValue: String
    let timeRangeRawValue: String
    let exportDate: Date
    let dataCount: Int
    let samples: [HistoricalSample]
    
    init(metricType: MetricType, timeRange: TimeRange, exportDate: Date, dataCount: Int, samples: [HistoricalSample]) {
        self.metricTypeRawValue = metricType.rawValue
        self.timeRangeRawValue = timeRange.rawValue
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
            self.value = sensorData.temperature
            self.additionalData = nil
        case .battery:
            self.value = Double(sensorData.batteryLevel)
            self.additionalData = [
                "voltage": Double(sensorData.batteryVoltage)
            ]
        case .accelerometer:
            self.value = sensorData.accelerometer.magnitude
            self.additionalData = [
                "x": Double(sensorData.accelerometer.x),
                "y": Double(sensorData.accelerometer.y),
                "z": Double(sensorData.accelerometer.z)
            ]
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
        let cacheKey = "\(metricType.rawValue)_\(timeRange.rawValue)_\(selectedDate.timeIntervalSince1970)"
        
        // Check cache first
        if let cached = cachedData[cacheKey] {
            self.processedData = cached
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Filter data based on time range and selected date
        let filteredData = filterData(from: ble.historicalData, timeRange: timeRange, selectedDate: selectedDate)
        
        guard !filteredData.isEmpty else {
            processedData = nil
            return
        }
        
        // Process data based on metric type and app mode
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
        
        // Cache the result
        cachedData[cacheKey] = processed
        
        // Clean cache if it gets too large
        if cachedData.count > 20 {
            let oldestKey = cachedData.keys.sorted().first!
            cachedData.removeValue(forKey: oldestKey)
        }
        
        self.processedData = processed
    }
    
    private func filterData(from data: [SensorData], timeRange: TimeRange, selectedDate: Date) -> [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            return data.filter { $0.timestamp >= startOfHour && $0.timestamp < endOfHour }
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return data.filter { $0.timestamp >= startOfDay && $0.timestamp < endOfDay }
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return data.filter { $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek }
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return data.filter { $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth }
        }
    }
    
    private func processMetricData(_ data: [SensorData], metricType: MetricType, appMode: AppMode) async -> [(timestamp: Date, value: Double)] {
        switch metricType {
        case .ppg:
            if appMode.allowsAdvancedAnalytics {
                // Use advanced PPG processing
                let rawPPG = data.map { (timestamp: $0.timestamp, ir: Double($0.ppg.ir), red: Double($0.ppg.red), green: Double($0.ppg.green)) }
                let normalized = normalizationService.normalizePPGData(rawPPG, method: .persistent, sensorData: data)
                return normalized.map { (timestamp: $0.timestamp, value: $0.ir) }
            } else {
                // Basic PPG processing for viewer mode
                return data.map { (timestamp: $0.timestamp, value: Double($0.ppg.ir)) }
            }
        case .temperature:
            return data.map { (timestamp: $0.timestamp, value: $0.temperature) }
        case .battery:
            return data.map { (timestamp: $0.timestamp, value: Double($0.batteryLevel)) }
        case .accelerometer:
            return data.map { (timestamp: $0.timestamp, value: $0.accelerometer.magnitude) }
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
        // Simplified segment detection
        var segments: [DataSegment] = []
        let windowSize = 5
        
        guard data.count > windowSize * 2 else { return [] }
        
        var currentStart = 0
        for i in windowSize..<(data.count - windowSize) {
            let window = Array(data[(i-windowSize)..<(i+windowSize)])
            let variation = calculateWindowVariation(window)
            
            if variation > 0.5 { // Movement threshold
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
        
        // Add final segment
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
        let tempChange = (recent.map { $0.temperature }.max() ?? 0) - (recent.map { $0.temperature }.min() ?? 0)
        let batteryLevel = recent.last?.batteryLevel ?? 0
        
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
            timeInState: 60.0 // Simplified
        )
    }
    
    func clearCache() {
        cachedData.removeAll()
    }
}

struct HistoricalDetailView: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedDate = Date() // For day view navigation
    @State private var selectedDataPoint: SensorData? // For tooltip
    
    // Data availability info
    private var dataAvailability: String {
        if ble.historicalData.isEmpty {
            return "No historical data collected yet"
        }
        
        guard let oldestData = ble.historicalData.first?.timestamp,
              let newestData = ble.historicalData.last?.timestamp else {
            return "No data available"
        }
        
        let duration = newestData.timeIntervalSince(oldestData)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "Data spans: \(hours)h \(minutes)m"
        } else {
            return "Data spans: \(minutes)m (need more time for trends)"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Selector
                TimeRangePicker(selectedRange: $selectedTimeRange)
                    .padding()
                    .onChange(of: selectedTimeRange) { _, _ in
                        selectedDate = Date() // Reset to today when time range changes
                    }
                
                // Date Navigation for all views
                DateNavigationView(selectedDate: $selectedDate, timeRange: selectedTimeRange)
                    .padding(.horizontal)
                
                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Enhanced Chart with Withings-style features
                        EnhancedHistoricalChartCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDate: selectedDate,
                            selectedDataPoint: $selectedDataPoint
                        )
                        
                        // Enhanced Statistics Card
                        EnhancedStatisticsCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange,
                            selectedDate: selectedDate
                        )
                        
                        // PPG Debug Card (only for PPG metric type)
                        if metricType == .ppg {
                            PPGDebugCard(
                                ble: ble,
                                timeRange: selectedTimeRange,
                                selectedDate: selectedDate
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("\(metricType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
            formatter.dateFormat = "HH:mm, dd MMM" // Fallback, should not be used
        case .day:
            formatter.dateFormat = "EEEE, dd MMMM"
        case .week:
            formatter.dateFormat = "dd MMM yyyy" // Show week start date
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        }
        return formatter
    }
    
    private var displayText: String {
        switch timeRange {
        case .hour:
            return "Hour View" // Fallback
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
    
    // Check if we can navigate forward (don't go beyond today)
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
                
                // Show current period indicator
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

// MARK: - Data Availability Banner
struct DataAvailabilityBanner: View {
    let dataCount: Int
    let availabilityText: String
    let oldestDate: Date?
    let newestDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Historical Data Collection")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text(availabilityText)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let oldest = oldestDate, let newest = newestDate {
                HStack(spacing: 4) {
                    Text("From:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(oldest, style: .date)
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("to")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(newest, style: .date)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Selected Range Info
struct SelectedRangeInfo: View {
    let timeRange: TimeRange
    let filteredDataCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Showing: Last \(timeRange.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if filteredDataCount == 0 {
                    Text("No data available for this time range")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("\(filteredDataCount) data points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Visual indicator of data sufficiency
            DataSufficiencyIndicator(
                timeRange: timeRange,
                dataCount: filteredDataCount
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Sufficiency Indicator
struct DataSufficiencyIndicator: View {
    let timeRange: TimeRange
    let dataCount: Int
    
    private var status: (text: String, color: Color, icon: String) {
        // Estimate minimum samples needed for meaningful historical view
        let minSamples: Int
        switch timeRange {
        case .hour: minSamples = 20 // ~1 per 3 min
        case .day: minSamples = 50 // ~1 per 30min
        case .week: minSamples = 100 // ~2 per day
        case .month: minSamples = 300 // ~10 per day
        }
        
        if dataCount == 0 {
            return ("No Data", .red, "exclamationmark.triangle.fill")
        } else if dataCount < minSamples / 2 {
            return ("Collecting", .orange, "hourglass")
        } else if dataCount < minSamples {
            return ("Partial", .yellow, "chart.line.uptrend.xyaxis")
        } else {
            return ("Complete", .green, "checkmark.circle.fill")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .font(.caption)
            Text(status.text)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.15))
        .cornerRadius(12)
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
    
    // Persistent state that remembers across data updates
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
            Date().timeIntervalSince(timestamp) > 300 // 5 minutes
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
        sensorData: [SensorData] = [] // For context analysis
    ) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        
        guard !data.isEmpty else { return data }
        
        // Update device context if sensor data is available
        if !sensorData.isEmpty {
            updateDeviceContext(from: sensorData)
        }
        
        // Choose method based on context if using persistent
        let actualMethod = method == .persistent ? 
            (deviceContext?.recommendedNormalization ?? .adaptiveBaseline) : method
        
        print("🔍 PPG Normalization: Using \(actualMethod.rawValue) (requested: \(method.rawValue))")
        
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
        
        // Analyze device state
        let accelerometerVariation = calculateMovementVariation(recentSamples)
        let temperatureChange = calculateTemperatureChange(recentSamples)
        let batteryLevel = recentSamples.last?.batteryLevel ?? 0
        let avgTemperature = recentSamples.map { $0.temperature }.reduce(0, +) / Double(recentSamples.count)
        
        let isMoving = accelerometerVariation > 0.3
        let temperatureStable = temperatureChange < 1.0
        let batteryCharging = batteryLevel > 95
        let isOnBody = avgTemperature > 25.0 && !isMoving // Simplified body detection
        
        // Calculate confidence based on consistency
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
        
        print("📊 Device Context: OnBody=\(isOnBody), Moving=\(isMoving), TempStable=\(temperatureStable), Confidence=\(String(format: "%.1f", confidence))")
    }
    
    private func persistentSmartNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        
        // Check if we need to establish or update baseline
        let shouldUpdateBaseline = baselineState == nil || 
                                  baselineState!.isStale || 
                                  (deviceContext?.isStable == true && !(baselineState?.isReliable ?? false))
        
        if shouldUpdateBaseline {
            updatePersistentBaseline(data)
        }
        
        guard let baseline = baselineState, baseline.isReliable else {
            print("⚠️ No reliable baseline, using adaptive normalization")
            return adaptiveBaselineNormalization(data)
        }
        
        print("✅ Using persistent baseline from \(baseline.timestamp) (\(baseline.sampleCount) samples)")
        
        // Apply persistent baseline correction with physiological scaling
        return data.map { sample in
            let correctedIR = sample.ir - baseline.irBaseline
            let correctedRed = sample.red - baseline.redBaseline  
            let correctedGreen = sample.green - baseline.greenBaseline
            
            // Scale to heart rate-like range (preserving signal characteristics)
            let scalingFactor: Double = deviceContext?.isOnBody == true ? 0.05 : 0.1
            
            return (
                timestamp: sample.timestamp,
                ir: 120 + (correctedIR * scalingFactor), // Center around 120 BPM
                red: 120 + (correctedRed * scalingFactor),
                green: 120 + (correctedGreen * scalingFactor)
            )
        }
    }
    
    private func updatePersistentBaseline(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) {
        // Use only stable data for baseline calculation
        guard let context = deviceContext, context.isStable else {
            print("🚫 Device not stable, skipping baseline update")
            return
        }
        
        // Use robust statistics (median instead of mean for outlier resistance)
        let irValues = data.map { $0.ir }.sorted()
        let redValues = data.map { $0.red }.sorted()
        let greenValues = data.map { $0.green }.sorted()
        
        guard !irValues.isEmpty else { return }
        
        let medianIndex = irValues.count / 2
        let irBaseline = irValues[medianIndex]
        let redBaseline = redValues[medianIndex]
        let greenBaseline = greenValues[medianIndex]
        
        // Calculate confidence based on data consistency
        let irStd = calculateStandardDeviation(irValues)
        let coefficientOfVariation = irStd / irBaseline
        let confidence = max(0.0, min(1.0, 1.0 - (coefficientOfVariation / 0.2))) // CV < 20% = high confidence
        
        baselineState = BaselineState(
            irBaseline: irBaseline,
            redBaseline: redBaseline,
            greenBaseline: greenBaseline,
            timestamp: Date(),
            confidence: confidence,
            sampleCount: data.count
        )
        
        print("📈 Updated persistent baseline - IR: \(String(format: "%.0f", irBaseline)), Confidence: \(String(format: "%.2f", confidence))")
    }
    
    // Helper methods
    private func calculateMovementVariation(_ samples: [SensorData]) -> Double {
        let magnitudes = samples.map { $0.accelerometer.magnitude }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(magnitudes.count)
        return sqrt(variance)
    }
    
    private func calculateTemperatureChange(_ samples: [SensorData]) -> Double {
        let temperatures = samples.map { $0.temperature }
        return (temperatures.max() ?? 0) - (temperatures.min() ?? 0)
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func adaptiveBaselineNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        // Use a sliding window baseline that adapts to slow changes
        let windowSize = min(10, data.count / 3)
        guard windowSize > 0 else { return data }
        
        return data.enumerated().map { index, sample in
            let windowStart = max(0, index - windowSize/2)
            let windowEnd = min(data.count, windowStart + windowSize)
            let window = Array(data[windowStart..<windowEnd])
            
            // Calculate baseline from window
            let irBaseline = window.map { $0.ir }.reduce(0, +) / Double(window.count)
            let redBaseline = window.map { $0.red }.reduce(0, +) / Double(window.count)
            let greenBaseline = window.map { $0.green }.reduce(0, +) / Double(window.count)
            
            // Apply baseline correction with amplification
            return (
                timestamp: sample.timestamp,
                ir: 100 + (sample.ir - irBaseline) * 0.1,  // Center around 100, amplify changes
                red: 100 + (sample.red - redBaseline) * 0.1,
                green: 100 + (sample.green - greenBaseline) * 0.1
            )
        }
    }
    
    private func dynamicRangeNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        // Use robust percentile-based normalization
        let irValues = data.map { $0.ir }.sorted()
        let redValues = data.map { $0.red }.sorted()
        let greenValues = data.map { $0.green }.sorted()
        
        // Use 10th and 90th percentiles for robust range
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
                ir: 50 + irNorm * 100,    // Scale to 50-150 range
                red: 50 + redNorm * 100,
                green: 50 + greenNorm * 100
            )
        }
    }
    
    private func heartRateSimulationNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        // Create heart rate-like visualization (60-180 bpm range)
        let irValues = data.map { $0.ir }
        let irMean = irValues.reduce(0, +) / Double(irValues.count)
        let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
        
        return data.map { sample in
            // Normalize to z-score, then map to HR range
            let irZ = irStd > 0 ? (sample.ir - irMean) / irStd : 0
            let simulatedHR = 120 + irZ * 20  // Center at 120 bpm, ±20 variation
            
            return (
                timestamp: sample.timestamp,
                ir: max(60, min(180, simulatedHR)),  // Clamp to realistic HR range
                red: sample.red,    // Keep original for comparison
                green: sample.green
            )
        }
    }
    
    // Public method to reset persistent state (useful for testing)
    func resetPersistentState() {
        baselineState = nil
        deviceContext = nil
        print("🔄 Reset persistent normalization state")
    }
    
    // Public method to get current state info
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
// MARK: - Enhanced Historical Chart Card (Withings-style)
struct EnhancedHistoricalChartCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    let selectedDate: Date
    @Binding var selectedDataPoint: SensorData?
    
    private var filteredData: [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            // This case should not be reached since we removed hour from picker
            return []
        case .day:
            // For day view, filter by the selected date
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.sorted { $0.timestamp < $1.timestamp }
        case .week:
            // For week view, show the week containing the selected date
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }.sorted { $0.timestamp < $1.timestamp }
        case .month:
            // For month view, show the month containing the selected date
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }.sorted { $0.timestamp < $1.timestamp }
        }
    }
    
    // Unified PPG normalization using the persistent service
    private var normalizedPPGData: [(timestamp: Date, value: Double)] {
        let rawData = filteredData.map { data in
            (timestamp: data.timestamp, ir: Double(data.ppg.ir), red: Double(data.ppg.red), green: Double(data.ppg.green))
        }
        guard !rawData.isEmpty else { return [] }
        
        // Use the unified normalization service with persistent smart normalization
        let normalized = PPGNormalizationService.shared.normalizePPGData(
            rawData, 
            method: .persistent,
            sensorData: filteredData  // Pass sensor data for context analysis
        )
        
        // Convert to the format expected by the chart (using IR channel)
        return normalized.map { (timestamp: $0.timestamp, value: $0.ir) }
    }
    
    private func getValue(from data: SensorData) -> Double {
        switch metricType {
        case .ppg: return Double(data.ppg.ir) // Use IR as primary PPG value
        case .temperature: return data.temperature
        case .battery: return Double(data.batteryLevel)
        case .accelerometer: return data.accelerometer.magnitude
        }
    }
    
    private var emptyStateMessage: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        switch timeRange {
        case .hour:
            return "Hour view not available" // Fallback
        case .day:
            formatter.dateStyle = .medium
            return "No measurements recorded on \(formatter.string(from: selectedDate))"
        case .week:
            formatter.dateFormat = "dd MMM"
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
                let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
                return "No measurements recorded from \(formatter.string(from: weekInterval.start)) - \(formatter.string(from: endDate))"
            }
            return "No measurements recorded for this week"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return "No measurements recorded in \(formatter.string(from: selectedDate))"
        }
    }
    
    private var debugInfo: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        
        let totalSamples = ble.historicalData.count
        let filteredSamples = filteredData.count
        
        var dateRange = ""
        if let first = filteredData.first?.timestamp, let last = filteredData.last?.timestamp {
            dateRange = "\(formatter.string(from: first)) - \(formatter.string(from: last))"
        }
        
        switch timeRange {
        case .hour:
            return "Hour: \(filteredSamples)/\(totalSamples) samples"
        case .day:
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            return "Day \(dayFormatter.string(from: selectedDate)): \(filteredSamples)/\(totalSamples) samples"
        case .week:
            return "Week: \(filteredSamples)/\(totalSamples) samples (\(dateRange))"
        case .month:
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM yyyy"
            return "Month \(monthFormatter.string(from: selectedDate)): \(filteredSamples)/\(totalSamples) samples"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and sample count with debug info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metricType.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Debug info to confirm static vs real-time behavior
                    Text(debugInfo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                Spacer()
            }
            
            if filteredData.isEmpty {
                // Empty state
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
                // Create the chart based on metric type
                Group {
                    if metricType == .ppg {
                        // PPG-specific chart with intelligent normalization
                        Chart {
                            ForEach(Array(normalizedPPGData.enumerated()), id: \.offset) { index, point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("PPG IR", point.value)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.catmullRom)
                                
                                // Add subtle area fill like Withings
                                AreaMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("PPG IR", point.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            
                            // Selection indicator
                            if let selected = selectedDataPoint {
                                // For PPG, show the normalized value at the selected point
                                let selectedNormalizedPoint = normalizedPPGData.first { 
                                    abs($0.timestamp.timeIntervalSince(selected.timestamp)) < 30 // Within 30 seconds
                                }
                                
                                if let normalizedPoint = selectedNormalizedPoint {
                                    PointMark(
                                        x: .value("Time", normalizedPoint.timestamp),
                                        y: .value("PPG IR", normalizedPoint.value)
                                    )
                                    .foregroundStyle(.blue)
                                    .symbol(.circle)
                                    .symbolSize(80)
                                    
                                    // Vertical rule mark for time indication
                                    RuleMark(
                                        x: .value("Time", normalizedPoint.timestamp)
                                    )
                                    .foregroundStyle(.gray.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1))
                                }
                            }
                        }
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                updateSelection(at: value.location, geometry: geometry, chartProxy: chartProxy)
                                            }
                                    )
                            }
                        }
                    } else {
                        // Original chart for non-PPG metrics
                        Chart {
                            ForEach(Array(filteredData.enumerated()), id: \.offset) { index, data in
                                LineMark(
                                    x: .value("Time", data.timestamp),
                                    y: .value(metricType.title, getValue(from: data))
                                )
                                .foregroundStyle(metricType.color)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                
                                AreaMark(
                                    x: .value("Time", data.timestamp),
                                    y: .value(metricType.title, getValue(from: data))
                                )
                                .foregroundStyle(metricType.color.opacity(0.1))
                            }
                            
                            // Selection indicator
                            if let selected = selectedDataPoint {
                                PointMark(
                                    x: .value("Time", selected.timestamp),
                                    y: .value(metricType.title, getValue(from: selected))
                                )
                                .foregroundStyle(metricType.color)
                                .symbol(.circle)
                                .symbolSize(100)
                                
                                RuleMark(
                                    x: .value("Time", selected.timestamp)
                                )
                                .foregroundStyle(.gray)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            }
                        }
                        .chartBackground { chartProxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                updateSelection(at: value.location, geometry: geometry, chartProxy: chartProxy)
                                            }
                                    )
                            }
                        }
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    switch timeRange {
                    case .hour:
                        // Should not be reached
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.minute())
                        }
                    case .day:
                        AxisMarks(values: .automatic(desiredCount: 7)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    case .week:
                        AxisMarks(values: .automatic(desiredCount: 7)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    case .month:
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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
                
                // Tooltip overlay
                if let selected = selectedDataPoint {
                    TooltipOverlay(
                        dataPoint: selected,
                        metricType: metricType,
                        value: {
                            if metricType == .ppg {
                                // For PPG, find the normalized value corresponding to the selected timestamp
                                let matchingNormalizedPoint = normalizedPPGData.first { 
                                    abs($0.timestamp.timeIntervalSince(selected.timestamp)) < 30 
                                }
                                return matchingNormalizedPoint?.value ?? getValue(from: selected)
                            } else {
                                return getValue(from: selected)
                            }
                        }()
                    )
                }
            }
            
            // Info message like Withings
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
    
    private func updateSelection(at location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) {
        // Use appropriate data source based on metric type
        let dataSource = metricType == .ppg ? normalizedPPGData.map { ($0.timestamp, $0.value) } : filteredData.map { ($0.timestamp, getValue(from: $0)) }
        guard !dataSource.isEmpty else { return }
        
        let plotAreaBounds = chartProxy.plotAreaFrame
        let plotAreaRect = geometry[plotAreaBounds]
        
        let relativeXPosition = location.x - plotAreaRect.origin.x
        let plotWidth = plotAreaRect.width
        let relativePosition = relativeXPosition / plotWidth
        
        guard relativePosition >= 0 && relativePosition <= 1 else { return }
        
        let timeRange = dataSource.last!.0.timeIntervalSince(dataSource.first!.0)
        let selectedTimeOffset = relativePosition * timeRange
        let selectedTime = dataSource.first!.0.addingTimeInterval(selectedTimeOffset)
        
        // Find the closest data point in the original filtered data
        let closest = filteredData.min { data1, data2 in
            abs(data1.timestamp.timeIntervalSince(selectedTime)) < 
            abs(data2.timestamp.timeIntervalSince(selectedTime))
        }
        
        selectedDataPoint = closest
    }
}

// MARK: - Tooltip Overlay
struct TooltipOverlay: View {
    let dataPoint: SensorData
    let metricType: MetricType
    let value: Double
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var valueText: String {
        switch metricType {
        case .ppg:
            // For PPG, show the normalized value as if it were a heart rate
            return String(format: "%.0f", value)
        case .temperature:
            return String(format: "%.1f°C", value)
        case .battery:
            return String(format: "%.0f%%", value)
        case .accelerometer:
            return String(format: "%.2f", value)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(timeFormatter.string(from: dataPoint.timestamp))
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
            // Small arrow pointing down
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

// MARK: - Enhanced Statistics Card
struct EnhancedStatisticsCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    let selectedDate: Date
    
    private var filteredData: [SensorData] {
        let calendar = Calendar.current
        
        switch timeRange {
        case .hour:
            // For hour view, show the hour containing the selected date/time
            let startOfHour = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfHour && $0.timestamp < endOfHour
            }
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
        case .week:
            // For week view, show the week containing the selected date
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }
        case .month:
            // For month view, show the month containing the selected date
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }
        }
    }
    
    private func getValue(from data: SensorData) -> Double {
        switch metricType {
        case .ppg: return Double(data.ppg.ir) // Use IR as primary PPG value
        case .temperature: return data.temperature
        case .battery: return Double(data.batteryLevel)
        case .accelerometer: return data.accelerometer.magnitude
        }
    }
    
    private var statistics: (average: Double, minimum: Double, maximum: Double) {
        let values = filteredData.map(getValue)
        guard !values.isEmpty else { return (0, 0, 0) }
        
        let avg = values.reduce(0, +) / Double(values.count)
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        
        return (avg, min, max)
    }
    
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
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !filteredData.isEmpty {
                let stats = statistics
                
                // Average (main stat like Withings)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatValue(stats.average))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(metricType.color)
                }
                
                Divider()
                
                // Min/Max stats
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

// MARK: - Extensions
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

// MARK: - Historical Chart Card
struct HistoricalChartCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    
    private var filteredData: [SensorData] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return ble.historicalData.filter { $0.timestamp >= cutoffDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metricType.icon)
                    .foregroundColor(metricType.color)
                Text("Historical Trend")
                    .font(.headline)
                Spacer()
                Text("\(filteredData.count) samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if filteredData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No data for this time range")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Keep device connected to collect historical data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else if filteredData.count < 10 {
                VStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Collecting data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Need more samples for meaningful trends (have \(filteredData.count), need ~20)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
            } else {
                if #available(iOS 16.0, *) {
                    switch metricType {
                    case .battery:
                        BatteryHistoricalChart(data: filteredData)
                    case .ppg:
                        PPGHistoricalChart(data: filteredData)
                    case .temperature:
                        TemperatureHistoricalChart(data: filteredData)
                    case .accelerometer:
                        AccelerometerHistoricalChart(data: filteredData)
                    }
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 250)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Battery Historical Chart
@available(iOS 16.0, *)
struct BatteryHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Voltage", Int(data[index].batteryVoltage))
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue) mV")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - PPG Historical Chart
@available(iOS 16.0, *)
struct PPGHistoricalChart: View {
    let data: [SensorData]
    @State private var showNormalized: Bool = false
    @State private var normalizationMethod: PPGNormalization = .minMax
    
    enum PPGNormalization: String, CaseIterable {
        case raw = "Raw"
        case minMax = "Min-Max"
        case zScore = "Z-Score"
        case percentage = "Percentage"
    }
    
    private var normalizedData: [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let rawData = data.map { sample in
            (timestamp: sample.timestamp, ir: Double(sample.ppg.ir), red: Double(sample.ppg.red), green: Double(sample.ppg.green))
        }
        
        guard showNormalized else {
            return rawData
        }
        
        return normalizeData(rawData, method: normalizationMethod)
    }
    
    private func normalizeData(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], method: PPGNormalization) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { return data }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        switch method {
        case .raw:
            return data
            
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
            
        case .zScore:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
            let redStd = sqrt(redValues.map { pow($0 - redMean, 2) }.reduce(0, +) / Double(redValues.count))
            let greenStd = sqrt(greenValues.map { pow($0 - greenMean, 2) }.reduce(0, +) / Double(greenValues.count))
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irStd > 0 ? (sample.ir - irMean) / irStd : 0,
                    red: redStd > 0 ? (sample.red - redMean) / redStd : 0,
                    green: greenStd > 0 ? (sample.green - greenMean) / greenStd : 0
                )
            }
            
        case .percentage:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMean > 0 ? ((sample.ir - irMean) / irMean) * 100 : 0,
                    red: redMean > 0 ? ((sample.red - redMean) / redMean) * 100 : 0,
                    green: greenMean > 0 ? ((sample.green - greenMean) / greenMean) * 100 : 0
                )
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Controls
            HStack {
                Toggle("Normalize", isOn: $showNormalized)
                    .font(.caption)
                
                if showNormalized {
                    Spacer()
                    
                    Picker("Method", selection: $normalizationMethod) {
                        ForEach(PPGNormalization.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                }
            }
            
            Chart {
                ForEach(normalizedData.indices, id: \.self) { index in
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("IR", normalizedData[index].ir)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("Red", normalizedData[index].red)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    LineMark(
                        x: .value("Time", normalizedData[index].timestamp),
                        y: .value("Green", normalizedData[index].green)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(formatYAxisLabel(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("IR").font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(.pink).frame(width: 8, height: 8)
                    Text("Red").font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("Green").font(.caption2)
                }
                Spacer()
            }
        }
    }
    
    private func formatYAxisLabel(_ value: Double) -> String {
        if showNormalized {
            switch normalizationMethod {
            case .raw:
                return String(format: "%.0f", value)
            case .minMax:
                return String(format: "%.2f", value)
            case .zScore:
                return String(format: "%.1f", value)
            case .percentage:
                return String(format: "%.0f%%", value)
            }
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Temperature Historical Chart
@available(iOS 16.0, *)
struct TemperatureHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Temperature", data[index].temperature)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Temperature", data[index].temperature)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.1f°C", doubleValue))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - Accelerometer Historical Chart
@available(iOS 16.0, *)
struct AccelerometerHistoricalChart: View {
    let data: [SensorData]
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("X", data[index].accelerometer.x)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Y", data[index].accelerometer.y)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Z", data[index].accelerometer.z)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Magnitude", data[index].accelerometer.magnitude)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .frame(height: 250)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }
}

// MARK: - Statistics Card
struct StatisticsCard: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    let timeRange: TimeRange
    
    private var filteredData: [SensorData] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return ble.historicalData.filter { $0.timestamp >= cutoffDate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
            
            if filteredData.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                switch metricType {
                case .battery:
                    BatteryStats(data: filteredData)
                case .ppg:
                    PPGStats(data: filteredData)
                case .temperature:
                    TemperatureStats(data: filteredData)
                case .accelerometer:
                    AccelerometerStats(data: filteredData)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Battery Stats
struct BatteryStats: View {
    let data: [SensorData]
    
    private var avgVoltage: Int {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0) { $0 + Int($1.batteryVoltage) }
        return sum / data.count
    }
    
    private var minVoltage: Int {
        data.map { Int($0.batteryVoltage) }.min() ?? 0
    }
    
    private var maxVoltage: Int {
        data.map { Int($0.batteryVoltage) }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Average", value: "\(avgVoltage) mV")
            StatRow(label: "Minimum", value: "\(minVoltage) mV")
            StatRow(label: "Maximum", value: "\(maxVoltage) mV")
        }
    }
}

// MARK: - PPG Stats
struct PPGStats: View {
    let data: [SensorData]
    
    private func average(for channel: KeyPath<PPGData, UInt32>) -> Int {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0) { $0 + Int($1.ppg[keyPath: channel]) }
        return sum / data.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "IR Average", value: "\(average(for: \.ir))")
            StatRow(label: "Red Average", value: "\(average(for: \.red))")
            StatRow(label: "Green Average", value: "\(average(for: \.green))")
        }
    }
}

// MARK: - Temperature Stats
struct TemperatureStats: View {
    let data: [SensorData]
    
    private var avgTemp: Double {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0.0) { $0 + $1.temperature }
        return sum / Double(data.count)
    }
    
    private var minTemp: Double {
        data.map { $0.temperature }.min() ?? 0
    }
    
    private var maxTemp: Double {
        data.map { $0.temperature }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Average", value: String(format: "%.1f°C", avgTemp))
            StatRow(label: "Minimum", value: String(format: "%.1f°C", minTemp))
            StatRow(label: "Maximum", value: String(format: "%.1f°C", maxTemp))
        }
    }
}

// MARK: - Accelerometer Stats
struct AccelerometerStats: View {
    let data: [SensorData]
    
    private var avgMagnitude: Double {
        guard !data.isEmpty else { return 0 }
        let sum = data.reduce(0.0) { $0 + $1.accelerometer.magnitude }
        return sum / Double(data.count)
    }
    
    private var maxMagnitude: Double {
        data.map { $0.accelerometer.magnitude }.max() ?? 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            StatRow(label: "Avg Magnitude", value: String(format: "%.2f", avgMagnitude))
            StatRow(label: "Max Magnitude", value: String(format: "%.2f", maxMagnitude))
        }
    }
}

// MARK: - Helper Views
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - PPG Debug Card
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
            case .onChargerStatic: return 10.0    // 10 seconds - stable power, minimal movement
            case .offChargerStatic: return 15.0   // 15 seconds - no power fluctuations but temperature changes
            case .inMotion: return 30.0           // 30 seconds - significant movement and sensor displacement
            case .onCheek: return 45.0            // 45 seconds - body heat, muscle movement, skin contact
            case .unknown: return 25.0            // 25 seconds - conservative default
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
        let confidence: Double // 0.0 to 1.0
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
            return ble.historicalData.filter { 
                $0.timestamp >= startOfHour && $0.timestamp < endOfHour
            }.suffix(20) // Show last 20 data points for debugging
        case .day:
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return ble.historicalData.filter { 
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.suffix(20)
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfWeek && $0.timestamp < endOfWeek
            }.suffix(20)
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
            return ble.historicalData.filter { 
                $0.timestamp >= startOfMonth && $0.timestamp < endOfMonth
            }.suffix(20)
        }
    }
    
    private var recentPPGData: [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let rawData = Array(filteredData.map { data in
            (timestamp: data.timestamp, ir: Double(data.ppg.ir), red: Double(data.ppg.red), green: Double(data.ppg.green))
        })
        
        // Show filtered data from the selected time period, not real-time data
        // This ensures the debug card shows the same static period as the main chart
        let staticData = Array(rawData.suffix(20)) // Last 20 from the filtered period
        
        // Use the unified service for consistency
        if normalizationMethod == .none {
            return staticData
        } else {
            // Convert our enum to the service enum
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
    
    // Separate function to update segments when needed
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
            
            // Update state history
            if stateHistory.isEmpty || stateHistory.last != context.state {
                stateHistory.append(context.state)
                lastStateChange = Date()
                
                // Keep only last 10 states
                if stateHistory.count > 10 {
                    stateHistory.removeFirst()
                }
            }
        }
    }
    
    private func detectDeviceState(from data: [SensorData]) -> DeviceContext? {
        guard data.count >= 5 else { return nil } // Need minimum samples
        
        // Get recent samples for analysis
        let recentSamples = Array(data.suffix(10))
        
        // Calculate metrics
        let accelerometerVariation = calculateAccelerometerVariation(recentSamples)
        let temperatureChange = calculateTemperatureChange(recentSamples)
        let batteryStatus = recentSamples.last?.batteryLevel ?? 0
        
        // Detect device state based on sensor fusion
        let detectedState = classifyDeviceState(
            accelerometerVariation: accelerometerVariation,
            temperatureChange: temperatureChange,
            batteryLevel: batteryStatus
        )
        
        // Calculate confidence based on consistency
        let confidence = calculateStateConfidence(detectedState, samples: recentSamples)
        
        // Calculate time in current state
        let timeInState = Date().timeIntervalSince(lastStateChange)
        
        // Determine if PPG should be considered stabilized
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
        
        return sqrt(variance) // Standard deviation
    }
    
    private func calculateTemperatureChange(_ samples: [SensorData]) -> Double {
        guard samples.count > 1 else { return 0 }
        
        let temperatures = samples.map { $0.temperature }
        let minTemp = temperatures.min() ?? 0
        let maxTemp = temperatures.max() ?? 0
        
        return maxTemp - minTemp
    }
    
    private func classifyDeviceState(
        accelerometerVariation: Double,
        temperatureChange: Double,
        batteryLevel: UInt8
    ) -> DeviceState {
        // Classification thresholds (these would be tuned based on actual device testing)
        let lowMovementThreshold = 0.1      // Very low accelerometer variation
        let moderateMovementThreshold = 0.5  // Moderate accelerometer variation
        let lowTempChangeThreshold = 0.5     // Small temperature change
        let moderateTempChangeThreshold = 2.0 // Moderate temperature change
        
        // Decision tree for state classification
        if batteryLevel > 95 && accelerometerVariation < lowMovementThreshold {
            // Very stable, high battery = likely on charger
            return .onChargerStatic
            
        } else if accelerometerVariation < lowMovementThreshold && temperatureChange < lowTempChangeThreshold {
            // Low movement, low temp change = off charger but static
            return .offChargerStatic
            
        } else if accelerometerVariation > moderateMovementThreshold {
            // High movement = being moved around
            return .inMotion
            
        } else if temperatureChange > moderateTempChangeThreshold && accelerometerVariation < moderateMovementThreshold {
            // Significant temperature change with low movement = likely on body (cheek)
            return .onCheek
            
        } else {
            return .unknown
        }
    }
    
    private func calculateStateConfidence(_ state: DeviceState, samples: [SensorData]) -> Double {
        guard samples.count >= 3 else { return 0.5 }
        
        // Calculate consistency of the detected state over recent samples
        var consistentSamples = 0
        
        for i in 1..<samples.count {
            let prevSample = samples[i-1]
            let currentSample = samples[i]
            
            let accelVariation = abs(currentSample.accelerometer.magnitude - prevSample.accelerometer.magnitude)
            let tempChange = abs(currentSample.temperature - prevSample.temperature)
            
            // Check if this sample is consistent with the detected state
            var isConsistent = false
            
            switch state {
            case .onChargerStatic, .offChargerStatic:
                isConsistent = accelVariation < 0.2 && tempChange < 1.0
            case .inMotion:
                isConsistent = accelVariation > 0.3
            case .onCheek:
                isConsistent = tempChange > 1.0 && accelVariation < 0.4
            case .unknown:
                isConsistent = true // Unknown state is always "consistent"
            }
            
            if isConsistent {
                consistentSamples += 1
            }
        }
        
        return Double(consistentSamples) / Double(samples.count - 1)
    }
    
    private func isDeviceStabilized(_ state: DeviceState, timeInState: TimeInterval, confidence: Double) -> Bool {
        // Require high confidence and sufficient time in state
        let requiredConfidence: Double = 0.7
        
        return confidence >= requiredConfidence && timeInState >= state.expectedStabilizationTime
    }
    
    
    private func detectDataSegments(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [DataSegment] {
        guard data.count >= 6 else { return [] }
        
        var segments: [DataSegment] = []
        var currentSegmentStart = 0
        let windowSize = 5 // Samples to analyze for stability
        let movementThreshold: Double = 1000 // Raw value change threshold indicating movement
        let stabilityDuration = 5 // Minimum samples needed to be considered stable
        
        var i = windowSize
        while i < data.count {
            // Calculate variation in the current window
            let windowData = Array(data[(i-windowSize)..<i])
            let variation = calculateWindowVariation(windowData)
            
            // Check if this indicates a significant movement
            let isMovement = variation > movementThreshold
            
            if isMovement || i == data.count - 1 {
                // End current segment
                let segmentEnd = i - windowSize
                if segmentEnd > currentSegmentStart + stabilityDuration {
                    // This segment is long enough to be considered stable
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
                
                // Start new segment after movement settles
                if isMovement {
                    // Skip ahead to allow sensor to settle
                    i += stabilityDuration
                    currentSegmentStart = i
                }
            }
            
            i += 1
        }
        
        // Add final segment if it's long enough
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
        
        // Calculate standard deviation for each channel
        func standardDeviation(_ values: [Double]) -> Double {
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            return sqrt(variance)
        }
        
        let irStd = standardDeviation(irValues)
        let redStd = standardDeviation(redValues)
        let greenStd = standardDeviation(greenValues)
        
        // Return maximum variation across all channels
        return max(irStd, max(redStd, greenStd))
    }
    
    private func normalizeData(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !data.isEmpty else { 
            print("❌ PPG Debug: No data to normalize")
            return data 
        }
        
        print("🔍 PPG Debug: Normalizing \(data.count) samples using \(normalizationMethod.rawValue)")
        
        if normalizationMethod == .adaptive {
            return adaptiveNormalization(data)
        }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        // Add debug info for raw values
        print("📊 Raw value ranges - IR: \(irValues.min() ?? 0)-\(irValues.max() ?? 0), Red: \(redValues.min() ?? 0)-\(redValues.max() ?? 0), Green: \(greenValues.min() ?? 0)-\(greenValues.max() ?? 0)")

        switch normalizationMethod {
        case .none:
            print("✅ Using raw values (no normalization)")
            return data
            
        case .zScore:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
            let redStd = sqrt(redValues.map { pow($0 - redMean, 2) }.reduce(0, +) / Double(redValues.count))
            let greenStd = sqrt(greenValues.map { pow($0 - greenMean, 2) }.reduce(0, +) / Double(greenValues.count))
            
            print("📈 Z-Score normalization - IR: mean=\(irMean), std=\(irStd)")
            
            // Handle zero standard deviation
            let normalizedData = data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irStd > 0 ? (sample.ir - irMean) / irStd : 0,
                    red: redStd > 0 ? (sample.red - redMean) / redStd : 0,
                    green: greenStd > 0 ? (sample.green - greenMean) / greenStd : 0
                )
            }
            print("✅ Z-Score normalization complete")
            return normalizedData
            
        case .minMax:
            let irMin = irValues.min() ?? 0
            let irMax = irValues.max() ?? 1
            let redMin = redValues.min() ?? 0
            let redMax = redValues.max() ?? 1
            let greenMin = greenValues.min() ?? 0
            let greenMax = greenValues.max() ?? 1
            
            print("📊 Min-Max ranges - IR: \(irMin)-\(irMax), Red: \(redMin)-\(redMax), Green: \(greenMin)-\(greenMax)")
            
            let normalizedData = data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0.5, // Default to middle if no range
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0.5,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0.5
                )
            }
            print("✅ Min-Max normalization complete")
            return normalizedData
            
        case .percentage:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            print("📊 Percentage normalization - IR mean: \(irMean), Red mean: \(redMean), Green mean: \(greenMean)")
            
            let normalizedData = data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMean > 0 ? ((sample.ir - irMean) / irMean) * 100 : 0,
                    red: redMean > 0 ? ((sample.red - redMean) / redMean) * 100 : 0,
                    green: greenMean > 0 ? ((sample.green - greenMean) / greenMean) * 100 : 0
                )
            }
            print("✅ Percentage normalization complete")
            return normalizedData
            
        case .baseline:
            // Use first 3 samples as baseline (if available)
            let baselineCount = min(3, data.count)
            guard baselineCount > 0 else { 
                print("❌ Baseline normalization: No baseline samples available")
                return data 
            }
            
            let irBaseline = Array(irValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let redBaseline = Array(redValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let greenBaseline = Array(greenValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            
            print("📊 Baseline values - IR: \(irBaseline), Red: \(redBaseline), Green: \(greenBaseline)")
            
            let normalizedData = data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: sample.ir - irBaseline,
                    red: sample.red - redBaseline,
                    green: sample.green - greenBaseline
                )
            }
            print("✅ Baseline normalization complete")
            return normalizedData
            
        case .adaptive:
            print("🔄 Using adaptive normalization")
            return adaptiveNormalization(data)
            
        case .contextAware:
            print("🧠 Using context-aware normalization")
            return contextAwareNormalization(data)
        }
    }
    
    private func contextAwareNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard let context = deviceContext else {
            print("⚠️ No device context available, using min-max normalization")
            return normalizeSegment(data, using: .minMax)
        }
        
        print("🧠 Context-aware normalization for state: \(context.state.rawValue)")
        print("📊 Confidence: \(String(format: "%.1f%%", context.confidence * 100))")
        print("⏱️ Time in state: \(String(format: "%.1f", context.timeInState))s / \(String(format: "%.0f", context.state.expectedStabilizationTime))s needed")
        
        // Choose normalization strategy based on device state
        switch context.state {
        case .onChargerStatic:
            // Most stable condition - use min-max for consistent baseline
            print("🔌 Using min-max normalization for stable charging state")
            return normalizeSegment(data, using: .minMax)
            
        case .offChargerStatic:
            // Stable but may have temperature drift - use baseline correction
            print("📱 Using baseline normalization for stable off-charger state")
            return normalizeSegment(data, using: .baseline)
            
        case .inMotion:
            // Unstable - don't normalize or use very gentle normalization
            if context.shouldNormalize {
                print("🚶‍♂️ Using gentle z-score normalization for motion state")
                return normalizeSegment(data, using: .zScore)
            } else {
                print("🚶‍♂️ Skipping normalization during motion (not stabilized)")
                return data // Raw values during motion
            }
            
        case .onCheek:
            // Body contact - use specialized approach for biological signals
            print("😊 Using specialized normalization for cheek contact")
            return normalizeForBiologicalContact(data, context: context)
            
        case .unknown:
            // Conservative approach
            print("❓ Using conservative baseline normalization for unknown state")
            return normalizeSegment(data, using: .baseline)
        }
    }
    
    private func normalizeForBiologicalContact(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], context: DeviceContext) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        // For biological contact, we expect:
        // 1. Higher baseline values due to skin contact
        // 2. Periodic variations due to heartbeat/muscle activity
        // 3. Temperature-related drift
        
        if !context.shouldNormalize {
            print("🫀 Biological signals not yet stabilized, using raw values")
            return data
        }
        
        // Use a modified baseline approach that accounts for biological variations
        guard data.count >= 5 else { return data }
        
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }
        
        // Use median of first 5 samples as baseline (more robust to outliers)
        let irBaseline = Array(irValues.prefix(5)).sorted()[2] // Median of 5
        let redBaseline = Array(redValues.prefix(5)).sorted()[2]
        let greenBaseline = Array(greenValues.prefix(5)).sorted()[2]
        
        print("🫀 Biological baseline - IR: \(irBaseline), Red: \(redBaseline), Green: \(greenBaseline)")
        
        // Apply gentle normalization that preserves biological signal characteristics
        let normalizedData = data.map { sample in
            (
                timestamp: sample.timestamp,
                ir: (sample.ir - irBaseline) * 0.1, // Scale down to preserve signal shape
                red: (sample.red - redBaseline) * 0.1,
                green: (sample.green - greenBaseline) * 0.1
            )
        }
        
        print("✅ Biological normalization complete")
        return normalizedData
    }
    
    private func adaptiveNormalization(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)]) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        guard !detectedSegments.isEmpty else {
            // If no segments detected yet, use min-max normalization on all data
            return normalizeSegment(data, using: .minMax)
        }
        
        var normalizedData: [(timestamp: Date, ir: Double, red: Double, green: Double)] = []
        
        for segment in detectedSegments {
            let segmentData = Array(data[segment.startIndex..<min(segment.endIndex, data.count)])
            
            if segment.isStable && segmentData.count >= 5 {
                // Use segment-specific normalization for stable segments
                let normalized = normalizeSegment(segmentData, using: .minMax)
                normalizedData.append(contentsOf: normalized)
            } else {
                // For unstable segments, use baseline correction from the segment start
                let normalized = normalizeSegment(segmentData, using: .baseline)
                normalizedData.append(contentsOf: normalized)
            }
        }
        
        return normalizedData
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
            // Use first sample as baseline for this segment
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.red)
                Text("PPG Channel Debug")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                
                // Temporary debug button - remove this later
                Button("Test") {
                    testNormalization()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
                
                Text("Last \(recentPPGData.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Normalization Method Picker
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
                    // Update segments when normalization method changes
                    updateSegmentsIfNeeded()
                }
                
                // Normalization explanation
                Text(normalizationExplanation)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                // Show persistent state for context-aware normalization
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
                
                // Show device context for context-aware normalization
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
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Status")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
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
                        
                        // Progress bar for stabilization
                        if !context.isStabilized {
                            let progress = min(1.0, context.timeInState / context.state.expectedStabilizationTime)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stabilization Progress")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: context.state.color))
                                    .frame(height: 4)
                                
                                Text("Ready for normalization in \(String(format: "%.0f", context.state.expectedStabilizationTime - context.timeInState))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Movement and temperature info
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Movement")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.3f", context.movementVariation))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Temp Change")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f°C", context.temperatureChange))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(8)
                    .background(context.state.color.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Show adaptive normalization info
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
                        
                        // Segment selector for detailed view
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
                    
                    // Debug info
                    Text("Filtered data count: \(filteredData.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 100)
            } else {
                VStack(spacing: 8) {
                    // Channel switching detection
                    if let detection = detectChannelSwitching() {
                        HStack {
                            Image(systemName: detection.isDetected ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(detection.isDetected ? .orange : .green)
                            Text(detection.message)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Recent values table
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            let displayData = getDisplayData()
                            ForEach(Array(displayData.enumerated().reversed()), id: \.offset) { index, data in
                                VStack(spacing: 4) {
                                    Text(timeFormatter.string(from: data.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(spacing: 2) {
                                        HStack {
                                            Circle()
                                                .fill(.red)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.ir))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        
                                        HStack {
                                            Circle()
                                                .fill(.pink)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.red))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                        
                                        HStack {
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 6, height: 6)
                                            Text(formatNormalizedValue(data.green))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    
                                    // Show segment indicator for adaptive mode
                                    if normalizationMethod == .adaptive {
                                        let segmentInfo = getSegmentInfo(for: index, in: displayData.count)
                                        if let info = segmentInfo {
                                            Circle()
                                                .fill(info.isStable ? .green : .orange)
                                                .frame(width: 4, height: 4)
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
                    
                    // Channel statistics
                    if let stats = calculateChannelStats() {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("IR Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.irAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Red Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.redAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Green Avg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatNormalizedValue(stats.greenAvg))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Variation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", stats.variation))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(stats.variation > 30 ? .orange : .primary)
                            }
                            
                            if normalizationMethod == .adaptive && !detectedSegments.isEmpty {
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Stability")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    let stableSegments = detectedSegments.filter { $0.isStable }.count
                                    Text("\(stableSegments)/\(detectedSegments.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(stableSegments == detectedSegments.count ? .green : .orange)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
        .onAppear {
            // Update segments when view appears
            updateSegmentsIfNeeded()
            
            // Start periodic context updates for context-aware normalization
            if normalizationMethod == .contextAware {
                startContextUpdates()
            }
        }
        .onDisappear {
            stopContextUpdates()
        }
    }
    

    
    // Temporary debug function - you can call this to test normalization
    private func testNormalization() {
        print("🧪 Testing PPG normalization...")
        
        // Create test data
        let testData = [
            (timestamp: Date(), ir: 1000.0, red: 800.0, green: 600.0),
            (timestamp: Date().addingTimeInterval(1), ir: 1100.0, red: 850.0, green: 650.0),
            (timestamp: Date().addingTimeInterval(2), ir: 1200.0, red: 900.0, green: 700.0),
            (timestamp: Date().addingTimeInterval(3), ir: 1050.0, red: 820.0, green: 630.0),
            (timestamp: Date().addingTimeInterval(4), ir: 1300.0, red: 950.0, green: 750.0)
        ]
        
        print("📊 Original test data:")
        for (index, data) in testData.enumerated() {
            print("  Sample \(index): IR=\(data.ir), Red=\(data.red), Green=\(data.green)")
        }
        
        // Test each normalization method
        for method in NormalizationMethod.allCases {
            print("\n🔬 Testing \(method.rawValue):")
            
            // This is a bit hacky but will show you what each method produces
            let normalized = normalizeTestData(testData, using: method)
            
            for (index, data) in normalized.enumerated() {
                print("  Sample \(index): IR=\(String(format: "%.3f", data.ir)), Red=\(String(format: "%.3f", data.red)), Green=\(String(format: "%.3f", data.green))")
            }
        }
        
        print("\n✅ Normalization test complete")
    }
    
    // Helper for testing
    private func normalizeTestData(_ data: [(timestamp: Date, ir: Double, red: Double, green: Double)], using method: NormalizationMethod) -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        let irValues = data.map { $0.ir }
        let redValues = data.map { $0.red }
        let greenValues = data.map { $0.green }

        switch method {
        case .none:
            return data
            
        case .zScore:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            let irStd = sqrt(irValues.map { pow($0 - irMean, 2) }.reduce(0, +) / Double(irValues.count))
            let redStd = sqrt(redValues.map { pow($0 - redMean, 2) }.reduce(0, +) / Double(redValues.count))
            let greenStd = sqrt(greenValues.map { pow($0 - greenMean, 2) }.reduce(0, +) / Double(greenValues.count))
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irStd > 0 ? (sample.ir - irMean) / irStd : 0,
                    red: redStd > 0 ? (sample.red - redMean) / redStd : 0,
                    green: greenStd > 0 ? (sample.green - greenMean) / greenStd : 0
                )
            }
            
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
                    ir: irMax > irMin ? (sample.ir - irMin) / (irMax - irMin) : 0.5,
                    red: redMax > redMin ? (sample.red - redMin) / (redMax - redMin) : 0.5,
                    green: greenMax > greenMin ? (sample.green - greenMin) / (greenMax - greenMin) : 0.5
                )
            }
            
        case .percentage:
            let irMean = irValues.reduce(0, +) / Double(irValues.count)
            let redMean = redValues.reduce(0, +) / Double(redValues.count)
            let greenMean = greenValues.reduce(0, +) / Double(greenValues.count)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: irMean > 0 ? ((sample.ir - irMean) / irMean) * 100 : 0,
                    red: redMean > 0 ? ((sample.red - redMean) / redMean) * 100 : 0,
                    green: greenMean > 0 ? ((sample.green - greenMean) / greenMean) * 100 : 0
                )
            }
            
        case .baseline:
            let baselineCount = min(3, data.count)
            guard baselineCount > 0 else { return data }
            
            let irBaseline = Array(irValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let redBaseline = Array(redValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            let greenBaseline = Array(greenValues.prefix(baselineCount)).reduce(0, +) / Double(baselineCount)
            
            return data.map { sample in
                (
                    timestamp: sample.timestamp,
                    ir: sample.ir - irBaseline,
                    red: sample.red - redBaseline,
                    green: sample.green - greenBaseline
                )
            }
            
        case .adaptive:
            // For testing, just use minMax
            return normalizeTestData(data, using: .minMax)
            
        case .contextAware:
            // For testing, just use minMax
            return normalizeTestData(data, using: .minMax)
        }
    }
    
    private func startContextUpdates() {
        // Update context every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if normalizationMethod == .contextAware {
                updateDeviceContext()
            }
        }
    }
    
    private func stopContextUpdates() {
        // Timer will be invalidated when view disappears
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
    
    private func detectChannelSwitching() -> (isDetected: Bool, message: String)? {
        guard recentPPGData.count >= 4 else { return nil }
        
        let recent = Array(recentPPGData.suffix(4))
        
        // Check if any channel values are switching positions
        var switchingDetected = false
        var patterns: [String] = []
        
        let tolerance: Double = normalizationMethod == .none ? 100 : 0.1 // Adjust tolerance based on normalization
        
        for i in 1..<recent.count {
            let prev = recent[i-1]
            let curr = recent[i]
            
            // Check if IR and Red values swapped
            if abs(prev.ir - curr.red) < tolerance && abs(prev.red - curr.ir) < tolerance {
                patterns.append("IR↔Red")
                switchingDetected = true
            }
            
            // Check if IR and Green values swapped
            if abs(prev.ir - curr.green) < tolerance && abs(prev.green - curr.ir) < tolerance {
                patterns.append("IR↔Green")
                switchingDetected = true
            }
            
            // Check if Red and Green values swapped
            if abs(prev.red - curr.green) < tolerance && abs(prev.green - curr.red) < tolerance {
                patterns.append("Red↔Green")
                switchingDetected = true
            }
        }
        
        if switchingDetected {
            let uniquePatterns = Array(Set(patterns))
            return (true, "⚠️ Channel switching detected: \(uniquePatterns.joined(separator: ", "))")
        } else {
            return (false, "✅ Channels appear stable")
        }
    }
    
    private func calculateChannelStats() -> (irAvg: Double, redAvg: Double, greenAvg: Double, variation: Double)? {
        let statsData = getDisplayData()
        guard !statsData.isEmpty else { return nil }
        
        let irValues = statsData.map { $0.ir }
        let redValues = statsData.map { $0.red }
        let greenValues = statsData.map { $0.green }
        
        let irAvg = irValues.reduce(0, +) / Double(irValues.count)
        let redAvg = redValues.reduce(0, +) / Double(redValues.count)
        let greenAvg = greenValues.reduce(0, +) / Double(greenValues.count)
        
        // Calculate coefficient of variation as a percentage
        let allValues = irValues + redValues + greenValues
        let overallAvg = allValues.reduce(0, +) / Double(allValues.count)
        let variance = allValues.map { pow($0 - overallAvg, 2) }.reduce(0, +) / Double(allValues.count)
        let stdDev = sqrt(variance)
        let variation = overallAvg != 0 ? (stdDev / abs(overallAvg)) * 100 : 0
        
        return (irAvg: irAvg, redAvg: redAvg, greenAvg: greenAvg, variation: variation)
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
            return "🧠 PERSISTENT SMART: Remembers baseline across sessions, adapts to device state (charging, on body, moving), preserves physiological signal patterns. This is the most advanced method."
        }
    }
    
    private func getDisplayData() -> [(timestamp: Date, ir: Double, red: Double, green: Double)] {
        if normalizationMethod == .adaptive && currentSegmentIndex >= 0 && currentSegmentIndex < detectedSegments.count {
            // Show only selected segment
            let segment = detectedSegments[currentSegmentIndex]
            let segmentData = Array(recentPPGData[segment.startIndex..<min(segment.endIndex, recentPPGData.count)])
            return segmentData
        } else {
            // Show all data (limited to last 20 for display)
            return Array(recentPPGData.suffix(20))
        }
    }
    
    private func getSegmentInfo(for index: Int, in displayCount: Int) -> (isStable: Bool, segmentIndex: Int)? {
        guard normalizationMethod == .adaptive && !detectedSegments.isEmpty else { return nil }
        
        // Map display index back to original data index
        let originalIndex = recentPPGData.count - displayCount + index
        
        // Find which segment this data point belongs to
        for (segmentIndex, segment) in detectedSegments.enumerated() {
            if originalIndex >= segment.startIndex && originalIndex < segment.endIndex {
                return (isStable: segment.isStable, segmentIndex: segmentIndex)
            }
        }
        
        return nil
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
}
