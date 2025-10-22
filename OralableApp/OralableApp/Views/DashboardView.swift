import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false
    
    @State private var selectedMetric: MetricType?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    ConnectionStatusCard(ble: ble, isViewerMode: isViewerMode)
                    
                    // Real-time Graphs Section
                    if ble.isConnected || !isViewerMode {
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
                            selectedMetric = .accelerometer
                        }
                    } else {
                        // Viewer Mode - Not Connected
                        ViewerModeEmptyState()
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .sheet(item: $selectedMetric) { metric in
                HistoricalDetailView(ble: ble, metricType: metric)
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
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Viewer Mode Empty State
struct ViewerModeEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Connect Device to View Real-time Data")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Viewer Mode does not support device connection")
                .font(.caption)
                .foregroundColor(.secondary)
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
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isConnected {
                content
                    .frame(height: 150)
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
                Text("Voltage: \(ble.sensorData.batteryVoltage) mV")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(ble.sensorData.batteryLevel)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
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
            } else {
                Text("Real-time graph (iOS 16+ required)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("IR: \(ble.sensorData.ppg.ir)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 8, height: 8)
                    Text("Red: \(ble.sensorData.ppg.red)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Green: \(ble.sensorData.ppg.green)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                Chart(recentData.indices, id: \.self) { index in
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
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis(.hidden)
            } else {
                Text("Real-time graph (iOS 16+ required)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                Text(String(format: "%.1f°C", ble.sensorData.temperature))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                Chart(recentData.indices, id: \.self) { index in
                    LineMark(
                        x: .value("Sample", index),
                        y: .value("Temperature", recentData[index].temperature)
                    )
                    .foregroundStyle(.orange)
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 30...40)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis(.hidden)
            } else {
                Text("Real-time graph (iOS 16+ required)")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("X: \(ble.sensorData.accelerometer.x)")
                        .font(.caption2)
                    Text("Y: \(ble.sensorData.accelerometer.y)")
                        .font(.caption2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Z: \(ble.sensorData.accelerometer.z)")
                        .font(.caption2)
                    Text(String(format: "Mag: %.2f", ble.sensorData.accelerometer.magnitude))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                Chart(recentData.indices, id: \.self) { index in
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
                        y: .value("Magnitude", recentData[index].accelerometer.magnitude)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis(.hidden)
            } else {
                Text("Real-time graph (iOS 16+ required)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Metric Type Enum
enum MetricType: String, Identifiable {
    case battery
    case ppg
    case temperature
    case accelerometer
    
    var id: String { rawValue }
    
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
