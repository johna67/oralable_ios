import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false
    
    @State private var selectedMetric: MetricType?
    @State private var selectedTimestamp: Date?
    
    // Determine if we should show graphs
    private var shouldShowGraphs: Bool {
        if isViewerMode {
            // Viewer Mode: Show graphs if we have imported data
            return !ble.historicalData.isEmpty
        } else {
            // Subscription Mode: Show graphs if connected OR if we have historical data
            return ble.isConnected || !ble.historicalData.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    ConnectionStatusCard(ble: ble, isViewerMode: isViewerMode)
                    
                    // Show graphs or empty state
                    if shouldShowGraphs {
                        // Battery Graph
                        MetricGraphCard(
                            title: "Battery",
                            icon: "battery.100",
                            color: .green,
                            isConnected: ble.isConnected
                        ) {
                            BatteryGraphView(ble: ble)
                        }
                        .onTapGesture {
                            selectedTimestamp = ble.lastUpdate
                            selectedMetric = .battery
                        }
                        
                        // PPG Graphs
                        MetricGraphCard(
                            title: "PPG Signals",
                            icon: "waveform.path.ecg",
                            color: .red,
                            isConnected: ble.isConnected
                        ) {
                            PPGGraphView(ble: ble)
                        }
                        .onTapGesture {
                            selectedTimestamp = ble.lastUpdate
                            selectedMetric = .ppg
                        }
                        
                        // Temperature Graph
                        MetricGraphCard(
                            title: "Temperature",
                            icon: "thermometer",
                            color: .orange,
                            isConnected: ble.isConnected
                        ) {
                            TemperatureGraphView(ble: ble)
                        }
                        .onTapGesture {
                            selectedTimestamp = ble.lastUpdate
                            selectedMetric = .temperature
                        }
                        
                        // Accelerometer Graph
                        MetricGraphCard(
                            title: "Accelerometer",
                            icon: "gyroscope",
                            color: .blue,
                            isConnected: ble.isConnected
                        ) {
                            AccelerometerGraphView(ble: ble)
                        }
                        .onTapGesture {
                            selectedTimestamp = ble.lastUpdate
                            selectedMetric = .accelerometer
                        }
                    } else {
                        // Empty state - no data available
                        ViewerModeEmptyState(isViewerMode: isViewerMode)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .sheet(item: $selectedMetric) { metric in
                if #available(iOS 16.0, *) {
                    HistoricalDetailSheet(
                        ble: ble, 
                        metricType: metric
                    )
                } else {
                    Text("Detailed view requires iOS 16+")
                        .padding()
                }
            }
        }
    }
}

// MARK: - Connection Status Card
struct ConnectionStatusCard: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(ble.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(ble.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
                    .foregroundColor(ble.isConnected ? .primary : .secondary)
                
                Spacer()
                
                if isViewerMode {
                    Text("Viewer Mode")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            
            if ble.isConnected {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ble.deviceName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last Update")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ble.lastUpdate, style: .relative)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            } else if !isViewerMode {
                Button(action: { ble.toggleScanning() }) {
                    HStack {
                        Image(systemName: ble.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                        Text(ble.isScanning ? "Stop Scanning" : "Start Scanning")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else if !ble.historicalData.isEmpty {
                // Viewer Mode with imported data
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Imported Data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(ble.historicalData.count) data points")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Viewer Mode Empty State
struct ViewerModeEmptyState: View {
    var isViewerMode: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isViewerMode ? "doc.badge.plus" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            if isViewerMode {
                Text("No Data Imported")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Import a CSV file to view historical data")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.blue)
                        Text("Go to the Share tab")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.blue)
                        Text("Tap \"Choose CSV File\"")
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(.blue)
                        Text("Select your exported data file")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
            } else {
                Text("No Device Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Connect your device to view real-time data")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Metric Graph Card
struct MetricGraphCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isConnected: Bool
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        isConnected: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isConnected = isConnected
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                if !isConnected {
                    Text("Historical")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Battery Graph View
struct BatteryGraphView: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentData: [SensorData] {
        Array(ble.historicalData.suffix(50))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !recentData.isEmpty {
                    let latestVoltage = recentData.last?.batteryVoltage ?? 0
                    let latestLevel = recentData.last?.batteryLevel ?? 0
                    Text("Voltage: \(latestVoltage) mV")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(latestLevel)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !recentData.isEmpty {
                if #available(iOS 16.0, *) {
                    Chart(recentData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Sample", index),
                            y: .value("Voltage", Int(recentData[index].batteryVoltage))
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 3000...4200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                }
            } else {
                VStack {
                    Text("No Data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - PPG Graph View
struct PPGGraphView: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentData: [SensorData] {
        Array(ble.historicalData.suffix(50))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !recentData.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("IR")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.ppg.ir ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Red")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.ppg.red ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.pink)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Green")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.ppg.green ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text("No Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !recentData.isEmpty {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(recentData.indices, id: \.self) { index in
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("IR", Int(recentData[index].ppg.ir))
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Red", Int(recentData[index].ppg.red))
                            )
                            .foregroundStyle(.pink)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Green", Int(recentData[index].ppg.green))
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                }
            } else {
                VStack {
                    Text("No Data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Temperature Graph View
struct TemperatureGraphView: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentData: [SensorData] {
        Array(ble.historicalData.suffix(50))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !recentData.isEmpty {
                    Text("Temperature")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.1f°C", recentData.last?.temperature ?? 0))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                } else {
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !recentData.isEmpty {
                if #available(iOS 16.0, *) {
                    Chart(recentData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Sample", index),
                            y: .value("Temp", recentData[index].temperature)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Sample", index),
                            y: .value("Temp", recentData[index].temperature)
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
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                }
            } else {
                VStack {
                    Text("No Data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Accelerometer Graph View
struct AccelerometerGraphView: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentData: [SensorData] {
        Array(ble.historicalData.suffix(50))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !recentData.isEmpty {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("X")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.accelerometer.x ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Y")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.accelerometer.y ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Z")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(recentData.last?.accelerometer.z ?? 0)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Mag")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f", recentData.last?.accelerometer.magnitude ?? 0))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                }
            } else {
                Text("No Data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !recentData.isEmpty {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(recentData.indices, id: \.self) { index in
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("X", recentData[index].accelerometer.x)
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Y", recentData[index].accelerometer.y)
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Z", recentData[index].accelerometer.z)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Mag", recentData[index].accelerometer.magnitude)
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 150)
                }
            } else {
                VStack {
                    Text("No Data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Metric Type Enum
enum MetricType: Identifiable {
    case battery
    case ppg
    case temperature
    case accelerometer
    
    var id: String {
        switch self {
        case .battery: return "battery"
        case .ppg: return "ppg"
        case .temperature: return "temperature"
        case .accelerometer: return "accelerometer"
        }
    }
    
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .ppg: return "PPG Signals"
        case .temperature: return "Temperature"
        case .accelerometer: return "Accelerometer"
        }
    }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .ppg: return "waveform.path.ecg"
        case .temperature: return "thermometer"
        case .accelerometer: return "gyroscope"
        }
    }
    
    var color: Color {
        switch self {
        case .battery: return .green
        case .ppg: return .red
        case .temperature: return .orange
        case .accelerometer: return .blue
        }
    }
}

// MARK: - Historical Detail Sheet Wrapper
struct HistoricalDetailSheet: View {
    @ObservedObject var ble: OralableBLE
    let metricType: MetricType
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeRange: TimeRange = .day
    
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
