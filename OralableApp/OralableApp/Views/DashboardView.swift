import SwiftUI

struct DashboardView: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status
                    ConnectionCard(ble: ble)
                    
                    // Battery and Temperature
                    HStack(spacing: 15) {
                        MetricCard(
                            title: "Battery",
                            value: "\(ble.sensorData.batteryLevel)%",
                            icon: "battery.100",
                            color: batteryColor(ble.sensorData.batteryLevel)
                        )
                        
                        MetricCard(
                            title: "Temperature",
                            value: String(format: "%.1f°C", ble.sensorData.temperature),
                            icon: "thermometer",
                            color: .orange
                        )
                    }
                    
                    // PPG Metrics
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PPG Signals")
                            .font(.headline)
                        
                        HStack(spacing: 15) {
                            SignalIndicator(
                                label: "IR",
                                value: ble.sensorData.ppg.ir,
                                color: .red
                            )
                            SignalIndicator(
                                label: "Red",
                                value: ble.sensorData.ppg.red,
                                color: .pink
                            )
                            SignalIndicator(
                                label: "Green",
                                value: ble.sensorData.ppg.green,
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Activity Level
                    ActivityGauge(activityLevel: ble.sensorData.activityLevel)
                }
                .padding()
            }
            .navigationTitle("Oralable Dashboard")
        }
    }
    
    private func batteryColor(_ level: UInt8) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

struct ConnectionCard: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(ble.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(ble.isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { ble.toggleScanning() }) {
                    Image(systemName: ble.isScanning ? "stop.circle" : "play.circle")
                        .font(.title2)
                }
            }
            
            if ble.isConnected {
                HStack {
                    Text("Device: \(ble.deviceName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Updated: \(ble.lastUpdate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SignalIndicator: View {
    let label: String
    let value: UInt32
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.caption2)
                .fontWeight(.medium)
            
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 4)
                .overlay(
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * min(Double(value) / 65535.0, 1.0))
                    }
                )
                .cornerRadius(2)
        }
    }
}

struct ActivityGauge: View {
    let activityLevel: UInt8
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Activity Level")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: CGFloat(activityLevel) / 255.0)
                    .stroke(
                        LinearGradient(colors: [.green, .yellow, .red],
                                      startPoint: .leading,
                                      endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(activityLevel)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .frame(width: 150, height: 150)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
