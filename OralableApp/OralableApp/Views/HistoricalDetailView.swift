import SwiftUI
import Charts

struct HistoricalDetailView: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .hour
    
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
                // Data Availability Banner
                if !ble.historicalData.isEmpty {
                    DataAvailabilityBanner(
                        dataCount: ble.historicalData.count,
                        availabilityText: dataAvailability,
                        oldestDate: ble.historicalData.first?.timestamp,
                        newestDate: ble.historicalData.last?.timestamp
                    )
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Time Range Selector
                TimeRangePicker(selectedRange: $selectedTimeRange)
                    .padding()
                
                // Historical Chart and Stats
                ScrollView {
                    VStack(spacing: 20) {
                        // Info about selected range
                        SelectedRangeInfo(
                            timeRange: selectedTimeRange,
                            filteredDataCount: filteredDataCount
                        )
                        
                        // Main Chart
                        HistoricalChartCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange
                        )
                        
                        // Statistics Card
                        StatisticsCard(
                            ble: ble,
                            metricType: metricType,
                            timeRange: selectedTimeRange
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle(metricType.title + " History")
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
    
    private var filteredDataCount: Int {
        let cutoffDate = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return ble.historicalData.filter { $0.timestamp >= cutoffDate }.count
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
        HStack(spacing: 0) {
            ForEach([TimeRange.hour, TimeRange.day, TimeRange.week], id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedRange == range ? Color.accentColor : Color(.systemGray6))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
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
    
    var body: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("IR", Int(data[index].ppg.ir))
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Red", Int(data[index].ppg.red))
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                
                LineMark(
                    x: .value("Time", data[index].timestamp),
                    y: .value("Green", Int(data[index].ppg.green))
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
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
