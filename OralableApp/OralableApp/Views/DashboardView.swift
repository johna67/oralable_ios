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
                        
                        // Heart Rate Graph (NEW)
                        MetricGraphCard(
                            title: "Heart Rate",
                            icon: "heart.fill",
                            color: .pink,
                            isConnected: ble.isConnected
                        ) {
                            HeartRateGraphView(ble: ble)
                        }
                        .onTapGesture {
                            selectedTimestamp = ble.lastUpdate
                            selectedMetric = .heartRate
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
                    HistoricalDetailView(
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
                
                Text(ble.isConnected ? "Connected" : (isViewerMode ? "Not Connected" : "Disconnected"))
                    .font(.headline)
                    .foregroundColor(ble.isConnected ? .green : .red)
                
                Spacer()
                
                if !ble.isConnected && !isViewerMode {
                    Button(action: {
                        ble.toggleScanning()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: ble.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                            Text(ble.isScanning ? "Stop Scanning" : "Start Scanning")
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            if !ble.isConnected && !isViewerMode && ble.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for devices...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !ble.historicalData.isEmpty && isViewerMode {
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
                    
                    VStack(alignment: .leading) {
                        Text("Level")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(latestLevel)%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Voltage")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(latestVoltage) mV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                            y: .value("Battery", recentData[index].batteryLevel)
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Sample", index),
                            y: .value("Battery", recentData[index].batteryLevel)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.0)],
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
                            .foregroundColor(.orange)
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
                                y: .value("IR", recentData[index].ppg.ir)
                            )
                            .foregroundStyle(.red)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Red", recentData[index].ppg.red)
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            
                            LineMark(
                                x: .value("Sample", index),
                                y: .value("Green", recentData[index].ppg.green)
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 1))
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

// MARK: - Heart Rate Graph View (NEW)
struct HeartRateGraphView: View {
    @ObservedObject var ble: OralableBLE
    
    private var recentData: [SensorData] {
        Array(ble.historicalData.suffix(50))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !recentData.isEmpty, let latest = recentData.last {
                    VStack(alignment: .leading) {
                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(latest.heartRate.displayText)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Quality")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(latest.heartRate.isValid ?
                                      (latest.heartRate.signalQuality >= 0.6 ? Color.green :
                                       latest.heartRate.signalQuality >= 0.3 ? Color.yellow : Color.red) :
                                      Color.gray)
                                .frame(width: 8, height: 8)
                            Text(latest.heartRate.qualityText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !recentData.isEmpty {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(recentData.indices, id: \.self) { index in
                            if recentData[index].heartRate.isValid {
                                LineMark(
                                    x: .value("Sample", index),
                                    y: .value("BPM", recentData[index].heartRate.bpm)
                                )
                                .foregroundStyle(.pink)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                
                                AreaMark(
                                    x: .value("Sample", index),
                                    y: .value("BPM", recentData[index].heartRate.bpm)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.pink.opacity(0.3), Color.pink.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    .chartYScale(domain: 40...180)
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
enum MetricType: String, Identifiable, Codable {
    case battery = "battery"
    case ppg = "ppg"
    case temperature = "temperature"
    case accelerometer = "accelerometer"
    case heartRate = "heartRate"
    
    var id: String {
        return self.rawValue
    }
    
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .ppg: return "PPG Signals"
        case .temperature: return "Temperature"
        case .accelerometer: return "Accelerometer"
        case .heartRate: return "Heart Rate"
        }
    }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .ppg: return "waveform.path.ecg"
        case .temperature: return "thermometer"
        case .accelerometer: return "gyroscope"
        case .heartRate: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .battery: return .green
        case .ppg: return .red
        case .temperature: return .orange
        case .accelerometer: return .blue
        case .heartRate: return .pink
        }
    }
    
    var csvHeaders: String {
        switch self {
        case .battery:
            return "Level,Voltage"
        case .ppg:
            return "IR,Red,Green"
        case .temperature:
            return "Temperature"
        case .accelerometer:
            return "X,Y,Z,Magnitude"
        case .heartRate:
            return "BPM,Quality"
        }
    }
    
    func csvValues(from sensorData: SensorData) -> String {
        switch self {
        case .battery:
            return "\(sensorData.batteryLevel),\(sensorData.batteryVoltage)"
        case .ppg:
            return "\(sensorData.ppg.ir),\(sensorData.ppg.red),\(sensorData.ppg.green)"
        case .temperature:
            return "\(sensorData.temperature)"
        case .accelerometer:
            return "\(sensorData.accelerometer.x),\(sensorData.accelerometer.y),\(sensorData.accelerometer.z),\(sensorData.accelerometer.magnitude)"
        case .heartRate:
            return "\(sensorData.heartRate.bpm),\(sensorData.heartRate.signalQuality)"
        }
    }
}
