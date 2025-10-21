import SwiftUI

struct DashboardView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false  // NEW: Flag to indicate Viewer Mode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status (different behavior in Viewer Mode)
                    ConnectionCard(ble: ble, isViewerMode: isViewerMode)
                    
                    Button("Test Aggregation") {
                        // Generate 24 hours of mock data
                        ble.generateMockHistoricalData(hours: 24)
                        
                        // Get day metrics
                        let dayMetrics = ble.getHistoricalMetrics(for: .day)
                        print("Day metrics: \(dayMetrics.totalSamples) samples")
                        print("Avg temp: \(dayMetrics.avgTemperature)°C")
                    }
                    
                    // Battery and Temperature (disabled/grayed in Viewer Mode if not connected)
                    HStack(spacing: 15) {
                        MetricCard(
                            title: "Battery",
                            value: "\(ble.sensorData.batteryLevel)%",
                            icon: "battery.100",
                            color: batteryColor(ble.sensorData.batteryLevel),
                            isDisabled: isViewerMode && !ble.isConnected
                        )
                        
                        MetricCard(
                            title: "Temperature",
                            value: String(format: "%.1f°C", ble.sensorData.temperature),
                            icon: "thermometer",
                            color: .orange,
                            isDisabled: isViewerMode && !ble.isConnected
                        )
                    }
                    
                    // PPG Metrics (disabled/grayed in Viewer Mode if not connected)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PPG Signals")
                            .font(.headline)
                            .foregroundColor(isViewerMode && !ble.isConnected ? .secondary : .primary)
                        
                        HStack(spacing: 15) {
                            SignalIndicator(
                                label: "IR",
                                value: ble.sensorData.ppg.ir,
                                color: .red,
                                isDisabled: isViewerMode && !ble.isConnected
                            )
                            SignalIndicator(
                                label: "Red",
                                value: ble.sensorData.ppg.red,
                                color: .pink,
                                isDisabled: isViewerMode && !ble.isConnected
                            )
                            SignalIndicator(
                                label: "Green",
                                value: ble.sensorData.ppg.green,
                                color: .green,
                                isDisabled: isViewerMode && !ble.isConnected
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .opacity(isViewerMode && !ble.isConnected ? 0.5 : 1.0)
                    
                    // Activity Level (disabled/grayed in Viewer Mode if not connected)
                    ActivityGauge(
                        activityLevel: Double(ble.sensorData.activityLevel),
                        isDisabled: isViewerMode && !ble.isConnected
                    )
                }
                .padding()
            }
            .navigationTitle("Oralable Dashboard")
        }
    }
    
    private func batteryColor(_ level: UInt8) -> Color {
        switch level {
        case UInt8(0)..<UInt8(20): return .red
        case UInt8(20)..<UInt8(50): return .orange
        default: return .green
        }
    }
}

struct ConnectionCard: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)
                
                Text(connectionStatusText)
                    .font(.headline)
                    .foregroundColor(connectionStatusColor)
            }
            
            if ble.isConnected {
                Text("Device: \(ble.deviceName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if isViewerMode {
                Text("Device connectivity disabled in Viewer Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(ble.isScanning ? "Scanning for devices..." : "Not connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Connection buttons (DISABLED in Viewer Mode)
            if !isViewerMode {
                if ble.isConnected {
                    Button(action: { ble.disconnect() }) {
                        Text("Disconnect")
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: { ble.toggleScanning() }) {
                        Text(ble.isScanning ? "Stop Scanning" : "Start Scanning")
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            } else {
                // Disabled button in Viewer Mode
                Button(action: {}) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        Text("Connection Unavailable")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(.secondary)
                    .cornerRadius(8)
                }
                .disabled(true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var connectionStatusColor: Color {
        if isViewerMode {
            return .gray
        }
        return ble.isConnected ? .green : .red
    }
    
    private var connectionStatusText: String {
        if isViewerMode {
            return "Viewer Mode"
        }
        return ble.isConnected ? "Connected" : "Disconnected"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(isDisabled ? .secondary : color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(isDisabled ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

struct SignalIndicator: View {
    let label: String
    let value: UInt32
    let color: Color
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isDisabled ? Color.gray : color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
                .monospaced()
                .foregroundColor(isDisabled ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityGauge: View {
    let activityLevel: Double
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Activity Level")
                .font(.headline)
                .foregroundColor(isDisabled ? .secondary : .primary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: min(activityLevel / 100.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: isDisabled ? [.gray, .gray] : [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.0f%%", activityLevel))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(isDisabled ? .secondary : .primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
