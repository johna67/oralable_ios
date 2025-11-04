//
//  DashboardView.swift
//  OralableApp
//
//  Updated: October 28, 2025
//  Added: SpO2 visualization and metric type
//

import SwiftUI
import Charts

// MARK: - Main Dashboard View

struct DashboardView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false
    
    var body: some View {
        NavigationLink {
            DeviceTestView()
        } label: {
            Text("🧪 Device Test")
                .font(DesignSystem.Typography.buttonMedium)
        }
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection Status Card (only in subscription mode)
                    if !isViewerMode {
                        ConnectionStatusCard(ble: ble)
                    }
                    
                    // Sensor Data Cards
                    if isViewerMode || ble.isConnected {
                        // Battery card
                        MetricGraphCard(metric: .battery) {
                            BatteryGraphView(batteryHistory: ble.batteryHistory)
                        }
                        
                        // PPG card
                        MetricGraphCard(metric: .ppg) {
                            PPGGraphView(ppgHistory: ble.ppgHistory)
                        }
                        
                        // Heart Rate card
                        MetricGraphCard(metric: .heartRate) {
                            HeartRateGraphView(heartRateHistory: ble.heartRateHistory)
                        }
                        
                        // SpO2 card
                        MetricGraphCard(metric: .spo2) {
                            SpO2GraphView(spo2History: ble.spo2History)
                        }
                        
                        // Temperature card
                        MetricGraphCard(metric: .temperature) {
                            TemperatureGraphView(temperatureHistory: ble.temperatureHistory)
                        }
                        
                        // Accelerometer card
                        MetricGraphCard(metric: .accelerometer) {
                            AccelerometerGraphView(accelerometerHistory: ble.accelerometerHistory)
                        }
                    } else {
                        // No Data State
                        NoDataView(isViewerMode: isViewerMode)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: ble.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundColor(ble.isConnected ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ble.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)
                        .foregroundColor(ble.isConnected ? .green : .red)
                    
                    Text(ble.isConnected ? ble.deviceName : "Tap to connect to device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !ble.isConnected {
                Button("Connect Device") {
                    // This would trigger connection logic
                    ble.startScanning()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - No Data View

struct NoDataView: View {
    let isViewerMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isViewerMode ? "doc.text.viewfinder" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 12) {
                Text(isViewerMode ? "No Data Available" : "Device Not Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(isViewerMode ? 
                     "Load data files to view sensor information" : 
                     "Connect your Oralable device to start monitoring")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isViewerMode {
                Button("Connect Device") {
                    // Trigger connection
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
}

// MARK: - Metric Graph Card

struct MetricGraphCard<Content: View>: View {
    let metric: MetricType
    let content: Content
    
    init(metric: MetricType, @ViewBuilder content: () -> Content) {
        self.metric = metric
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metric.icon)
                    .font(.title3)
                    .foregroundColor(metric.color)
                
                Text(metric.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    // Navigate to detailed view
                }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            content
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Graph Views
// These would be implemented with actual graph content

struct BatteryGraphView: View {
    let batteryHistory: [BatteryData]
    
    var body: some View {
        VStack {
            Text("Battery Graph")
            Text("Implementation needed")
        }
        .frame(height: 100)
    }
}

struct PPGGraphView: View {
    let ppgHistory: [PPGData]
    
    var body: some View {
        VStack {
            Text("PPG Graph")
            Text("Implementation needed")
        }
        .frame(height: 100)
    }
}

struct HeartRateGraphView: View {
    let heartRateHistory: [HeartRateData]
    
    var body: some View {
        VStack {
            Text("Heart Rate Graph")
            Text("Implementation needed")
        }
        .frame(height: 100)
    }
}

struct TemperatureGraphView: View {
    let temperatureHistory: [TemperatureData]
    
    var body: some View {
        VStack {
            Text("Temperature Graph")
            Text("Implementation needed")
        }
        .frame(height: 100)
    }
}

struct AccelerometerGraphView: View {
    let accelerometerHistory: [AccelerometerData]
    
    var body: some View {
        VStack {
            Text("Accelerometer Graph")
            Text("Implementation needed")
        }
        .frame(height: 100)
    }
}

// MARK: - SpO2 Graph View Component

/// SpO2 Graph View for blood oxygen saturation monitoring
struct SpO2GraphView: View {
    let spo2History: [SpO2Data]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with current value
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = spo2History.last, latest.isValid {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(latest.percentage))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("%")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        // Health status
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorForStatus(latest.healthStatus))
                                .frame(width: 8, height: 8)
                            
                            Text(latest.healthStatus)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("No Signal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Signal quality indicator
                if let latest = spo2History.last {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForQuality(latest.qualityColor))
                                .frame(width: 10, height: 10)
                            
                            Text(latest.qualityLevel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Signal Quality")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Chart
            if !spo2History.isEmpty {
                Chart {
                    ForEach(Array(spo2History.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("SpO2", measurement.percentage)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("SpO2", measurement.percentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Reference line at 95% (normal threshold)
                    RuleMark(y: .value("Normal", 95))
                        .foregroundStyle(Color.green.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartYScale(domain: 85...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                // Empty state
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No SpO2 Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            }
            
            // Info footer
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Normal range: 95-100%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let latest = spo2History.last {
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func colorForQuality(_ qualityColor: String) -> Color {
        switch qualityColor {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "Normal": return .green
        case "Borderline": return .yellow
        case "Low": return .orange
        default: return .red
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock OralableBLE for preview
        DashboardView(ble: OralableBLE())
    }
}

struct SpO2GraphView_Previews: PreviewProvider {
    static var previews: some View {
        SpO2GraphView(spo2History: [
            SpO2Data(percentage: 98.0, quality: 0.95, timestamp: Date().addingTimeInterval(-300)),
            SpO2Data(percentage: 97.5, quality: 0.90, timestamp: Date().addingTimeInterval(-240)),
            SpO2Data(percentage: 98.2, quality: 0.92, timestamp: Date().addingTimeInterval(-180)),
            SpO2Data(percentage: 97.8, quality: 0.88, timestamp: Date().addingTimeInterval(-120)),
            SpO2Data(percentage: 98.5, quality: 0.94, timestamp: Date().addingTimeInterval(-60)),
            SpO2Data(percentage: 98.0, quality: 0.93, timestamp: Date())
        ])
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif



