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
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Connection Status Card (only in subscription mode)
                    if !isViewerMode {
                        ConnectionStatusCard(ble: ble)
                    }
                    
                    // Device State Card (shows what the device is doing)
                    if ble.isConnected || isViewerMode {
                        DeviceStateCard(deviceState: ble.deviceState)
                    }
                    
                    // Sensor Data Cards
                    if isViewerMode || ble.isConnected {
                        // Battery card
                        MetricGraphCard(metric: .battery) {
                            BatteryGraphView(batteryHistory: ble.batteryHistory)
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
                        
                        // PPG card (last - most technical)
                        MetricGraphCard(metric: .ppg) {
                            PPGGraphView(ppgHistory: ble.ppgHistory)
                        }
                        .environmentObject(ble)
                    } else {
                        // No Data State
                        NoDataView(isViewerMode: isViewerMode)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .background(DesignSystem.Colors.backgroundSecondary.ignoresSafeArea())
        }
    }
}

// MARK: - Device State Card

struct DeviceStateCard: View {
    let deviceState: DeviceStateResult?
    
    private var stateColor: Color {
        guard let state = deviceState?.state else { return .gray }
        switch state.color {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "gray": return .gray
        default: return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // State Icon
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: deviceState?.state.icon ?? "questionmark.circle")
                        .font(.system(size: DesignSystem.Sizing.Icon.lg))
                        .foregroundColor(stateColor)
                }
                
                // State Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(deviceState?.state.rawValue ?? "Unknown")
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if let state = deviceState {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: DesignSystem.Sizing.Icon.xs))
                                .foregroundColor(confidenceColor(state.confidence))
                            
                            Text("\(state.confidenceDescription) Confidence")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Description
            if let state = deviceState?.state {
                Divider()
                
                Text(state.description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineSpacing(4)
            }
            
            // Detailed metrics (collapsible)
            if let deviceState = deviceState, !deviceState.details.isEmpty {
                DisclosureGroup("Details") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        ForEach(Array(deviceState.details.keys.sorted()), id: \.self) { key in
                            if key != "reason" {
                                HStack {
                                    Text(key.capitalized)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                    
                                    Spacer()
                                    
                                    Text(formatValue(deviceState.details[key]))
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    .padding(.top, DesignSystem.Spacing.xs)
                }
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.md)
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.75...1.0:
            return .green
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }
    
    private func formatValue(_ value: Any?) -> String {
        guard let value = value else { return "N/A" }
        
        if let doubleValue = value as? Double {
            return String(format: "%.1f", doubleValue)
        } else if let intValue = value as? Int {
            return "\(intValue)"
        } else if let stringValue = value as? String {
            return stringValue
        } else {
            return String(describing: value)
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(ble.isConnected ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Image(systemName: ble.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: DesignSystem.Sizing.Icon.lg))
                    .foregroundColor(ble.isConnected ? .green : .red)
            }
            
            // Status Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(ble.isConnected ? "Connected" : "Disconnected")
                    .font(DesignSystem.Typography.h4)
                    .foregroundColor(ble.isConnected ? .green : .red)
                
                Text(ble.isConnected ? ble.deviceName : "No device connected")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Connect Button (if disconnected)
            if !ble.isConnected {
                Button("Connect") {
                    ble.startScanning()
                }
                .font(DesignSystem.Typography.buttonSmall)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color.blue)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.md)
    }
}

// MARK: - No Data View

struct NoDataView: View {
    let isViewerMode: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.backgroundTertiary)
                    .frame(width: 120, height: 120)
                
                Image(systemName: isViewerMode ? "doc.text.magnifyingglass" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.textDisabled)
            }
            
            // Message
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(isViewerMode ? "No Data Available" : "Device Not Connected")
                    .font(DesignSystem.Typography.h2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(isViewerMode ?
                     "Import a CSV file to view sensor data" :
                     "Connect your Oralable device to start monitoring")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            
            // Action Button
            if !isViewerMode {
                Button(action: {}) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "wave.3.right")
                        Text("Connect Device")
                    }
                    .font(DesignSystem.Typography.buttonMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(Color.blue)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                    .designShadow(DesignSystem.Shadow.md)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxxl)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.sm)
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
    
    // Show only last 3 minutes of data
    private var recentData: [BatteryData] {
        let threeMinutesAgo = Date().addingTimeInterval(-180) // 3 minutes = 180 seconds
        return batteryHistory.filter { $0.timestamp >= threeMinutesAgo }
    }
    
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
            
            if !recentData.isEmpty {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Battery", measurement.percentage)
                        )
                        .foregroundStyle(Color.green)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
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
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
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
    
    // Show only last 3 minutes of data
    private var recentData: [PPGData] {
        let threeMinutesAgo = Date().addingTimeInterval(-180)
        return ppgHistory.filter { $0.timestamp >= threeMinutesAgo }
    }
    
    // Calculate dynamic Y-axis range based on actual data
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 0...100000 }
        
        let values = recentData.map { Double($0.ir) }
        
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...100000
        }
        
        // Add 10% padding above and below
        let range = maxValue - minValue
        let padding = max(range * 0.1, 1000) // At least 1000 units padding
        
        let lower = max(0, minValue - padding)
        let upper = maxValue + padding
        
        return lower...upper
    }
    
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
            
            if !recentData.isEmpty {
                Chart {
                    // IR channel (primary)
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("IR", measurement.ir)
                        )
                        .foregroundStyle(Color.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue / 1000)K")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
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
    
    // Show only last 3 minutes of data
    private var recentData: [HeartRateData] {
        let threeMinutesAgo = Date().addingTimeInterval(-180) // 3 minutes = 180 seconds
        return heartRateHistory.filter { $0.timestamp >= threeMinutesAgo }
    }
    
    // Calculate dynamic Y-axis range based on actual data
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 40...120 }
        
        let values = recentData.map { $0.bpm }
        
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 40...120
        }
        
        // Round to nearest 10 and add padding
        let lower = max(40, floor((minValue - 10) / 10) * 10)
        let upper = min(200, ceil((maxValue + 10) / 10) * 10)
        
        // Ensure minimum range of 40 BPM
        let range = upper - lower
        if range < 40 {
            let mid = (lower + upper) / 2
            return (mid - 20)...(mid + 20)
        }
        
        return lower...upper
    }
    
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
            
            if !recentData.isEmpty {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("BPM", measurement.bpm)
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
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
                    
                    // Normal range reference lines (only if in view)
                    if yAxisRange.contains(60) {
                        RuleMark(y: .value("Normal Low", 60))
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    
                    if yAxisRange.contains(100) {
                        RuleMark(y: .value("Normal High", 100))
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel()
                        AxisGridLine()
                    }
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
    
    // Show only last 3 minutes of data
    private var recentData: [TemperatureData] {
        let threeMinutesAgo = Date().addingTimeInterval(-180) // 3 minutes = 180 seconds
        return temperatureHistory.filter { $0.timestamp >= threeMinutesAgo }
    }
    
    // Calculate dynamic Y-axis range based on actual data
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 20...40 }
        
        let values = recentData.map { $0.celsius }
        
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 20...40
        }
        
        // For temperature, use tighter bounds around typical body temp
        let lower = max(15, floor(minValue - 2))
        let upper = min(45, ceil(maxValue + 2))
        
        // Ensure minimum range of 8°C for meaningful visualization
        let range = upper - lower
        if range < 8 {
            let mid = (lower + upper) / 2
            return (mid - 4)...(mid + 4)
        }
        
        return lower...upper
    }
    
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
            
            if !recentData.isEmpty {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Temperature", measurement.celsius)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
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
                    
                    // Normal body temperature reference (only if in view)
                    if yAxisRange.contains(37.0) {
                        RuleMark(y: .value("Normal", 37.0))
                            .foregroundStyle(Color.green.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(String(format: "%.1f°", doubleValue))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
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
    
    // Show only last 3 minutes of data
    private var recentData: [AccelerometerData] {
        let threeMinutesAgo = Date().addingTimeInterval(-180) // 3 minutes = 180 seconds
        return accelerometerHistory.filter { $0.timestamp >= threeMinutesAgo }
    }
    
    // Calculate dynamic Y-axis range based on actual data
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 0...500 }
        
        let values = recentData.map { $0.magnitude }
        
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...500
        }
        
        // Always start from 0 for magnitude
        let lower: Double = 0
        
        // Round up to nearest 100 and add padding
        let upper = ceil((maxValue + 50) / 100) * 100
        
        // Ensure minimum range of 200 for meaningful visualization
        let range = upper - lower
        if range < 200 {
            return 0...200
        }
        
        return lower...upper
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = accelerometerHistory.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.0f", latest.magnitude))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("mg")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(latest.isMoving ? "Movement Detected" : "Stationary")
                            .font(.subheadline)
                            .foregroundColor(latest.isMoving ? .orange : .secondary)
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
            
            if !recentData.isEmpty {
                Chart {
                    // Magnitude line
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Magnitude", measurement.magnitude)
                        )
                        .foregroundStyle(Color.purple)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    
                    // Area under the curve
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Magnitude", measurement.magnitude)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Movement threshold reference line (only if in view)
                    if yAxisRange.contains(100) {
                        RuleMark(y: .value("Movement Threshold", 100))
                            .foregroundStyle(Color.orange.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel()
                        AxisGridLine()
                    }
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
    
    // Show only last 3 minutes of data
    private var recentData: [SpO2Data] {
        let threeMinutesAgo = Date().addingTimeInterval(-180) // 3 minutes = 180 seconds
        return spo2History.filter { $0.timestamp >= threeMinutesAgo }
    }
    
    // Calculate dynamic Y-axis range based on actual data
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 90...100 }
        
        let values = recentData.map { $0.percentage }
        
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 90...100
        }
        
        // For SpO2, use tight bounds around normal range (95-100%)
        let lower = max(80, floor(minValue - 2))
        let upper = min(100, ceil(maxValue + 1))
        
        // Ensure minimum range of 10% for meaningful visualization
        let range = upper - lower
        if range < 10 {
            let mid = (lower + upper) / 2
            return max(80, mid - 5)...min(100, mid + 5)
        }
        
        return lower...upper
    }
    
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
            if !recentData.isEmpty {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("SpO2", measurement.percentage)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
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
                    
                    // Reference line at 95% (normal threshold) - only if in view
                    if yAxisRange.contains(95) {
                        RuleMark(y: .value("Normal", 95))
                            .foregroundStyle(Color.green.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 120)
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
                .frame(height: 120)
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



