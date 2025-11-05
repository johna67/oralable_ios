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
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Device Test Button
                    NavigationLink {
                        DeviceTestView()
                    } label: {
                        HStack {
                            Image(systemName: "flask.fill")
                            Text("Device Test")
                        }
                        .font(DesignSystem.Typography.buttonMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
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
                        .environmentObject(ble)
                        
                        // PPG card
                        MetricGraphCard(metric: .ppg) {
                            PPGGraphView(ppgHistory: ble.ppgHistory)
                        }
                        .environmentObject(ble)
                        
                        // Heart Rate card
                        MetricGraphCard(metric: .heartRate) {
                            HeartRateGraphView(heartRateHistory: ble.heartRateHistory)
                        }
                        .environmentObject(ble)
                        
                        // SpO2 card
                        MetricGraphCard(metric: .spo2) {
                            SpO2GraphView(spo2History: ble.spo2History)
                        }
                        .environmentObject(ble)
                        
                        // Temperature card
                        MetricGraphCard(metric: .temperature) {
                            TemperatureGraphView(temperatureHistory: ble.temperatureHistory)
                        }
                        .environmentObject(ble)
                        
                        // Accelerometer card
                        MetricGraphCard(metric: .accelerometer) {
                            AccelerometerGraphView(accelerometerHistory: ble.accelerometerHistory)
                        }
                        .environmentObject(ble)
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
    @EnvironmentObject var ble: OralableBLE
    
    init(metric: MetricType, @ViewBuilder content: () -> Content) {
        self.metric = metric
        self.content = content()
    }
    
    var body: some View {
        NavigationLink(destination: HistoricalDetailView(ble: ble, metricType: metric)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.title3)
                        .foregroundColor(metric.color)
                    
                    Text(metric.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                content
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Graph Views
// These would be implemented with actual graph content

struct BatteryGraphView: View {
    let batteryHistory: [BatteryData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = batteryHistory.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(latest.percentage)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("%")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(latest.status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("No Data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if !batteryHistory.isEmpty {
                Chart {
                    ForEach(Array(batteryHistory.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Battery", measurement.percentage)
                        )
                        .foregroundStyle(Color.green)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Battery", measurement.percentage)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct PPGGraphView: View {
    let ppgHistory: [PPGData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = ppgHistory.last {
                        Text("IR: \(latest.ir)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Text("R: \(latest.red) G: \(latest.green)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("No Signal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if !ppgHistory.isEmpty {
                let recentData = Array(ppgHistory.suffix(50))
                
                Chart {
                    // IR channel (primary)
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("IR", measurement.ir)
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct HeartRateGraphView: View {
    let heartRateHistory: [HeartRateData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = heartRateHistory.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(latest.bpm))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("BPM")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(latest.zone)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            }
            .padding(.horizontal, 4)
            
            if !heartRateHistory.isEmpty {
                Chart {
                    ForEach(Array(heartRateHistory.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("BPM", measurement.bpm)
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("BPM", measurement.bpm)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red.opacity(0.3), Color.red.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Normal range reference lines
                    RuleMark(y: .value("Normal Low", 60))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    RuleMark(y: .value("Normal High", 100))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartYScale(domain: 40...200)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct TemperatureGraphView: View {
    let temperatureHistory: [TemperatureData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = temperatureHistory.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", latest.celsius))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("°C")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "%.1f°F", latest.fahrenheit))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("No Data")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if !temperatureHistory.isEmpty {
                Chart {
                    ForEach(Array(temperatureHistory.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Temperature", measurement.celsius)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Temperature", measurement.celsius)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Normal body temperature reference
                    RuleMark(y: .value("Normal", 37.0))
                        .foregroundStyle(Color.green.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartYScale(domain: 32...42)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct AccelerometerGraphView: View {
    let accelerometerHistory: [AccelerometerData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = accelerometerHistory.last {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("X: \(latest.x)  Y: \(latest.y)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Z: \(latest.z)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("mg (milligravity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("No Data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if !accelerometerHistory.isEmpty {
                let recentData = Array(accelerometerHistory.suffix(50))
                
                Chart {
                    // X axis
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("X", measurement.x)
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    
                    // Y axis
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Y", measurement.y)
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    
                    // Z axis
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Z", measurement.z)
                        )
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            }
        }
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



