//
//  DashboardView.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Integrated with DashboardViewModel (MVVM Architecture)
//

import SwiftUI
import Charts

// MARK: - Main Dashboard View

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    var isViewerMode: Bool = false
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private var columns: [GridItem] {
        let columnCount = DesignSystem.Layout.gridColumns(for: sizeClass)
        return Array(
            repeating: GridItem(.flexible(), spacing: DesignSystem.Layout.cardSpacing),
            count: columnCount
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Connection Status Card (only in subscription mode)
                if !isViewerMode {
                    ConnectionStatusCard(viewModel: viewModel)
                        .frame(maxWidth: .infinity)
                }
                
                // Device State Card (shows what the device is doing)
                if viewModel.isConnected || isViewerMode {
                    DeviceStateCard(deviceState: viewModel.deviceState)
                        .frame(maxWidth: .infinity)
                }
                
                // Sensor Data Cards in Adaptive Grid
                if isViewerMode || viewModel.isConnected {
                    LazyVGrid(columns: columns, spacing: DesignSystem.Layout.cardSpacing) {
                        // Battery card
                        MetricGraphCard(metric: .battery) {
                            BatteryGraphView(batteryHistory: viewModel.batteryHistory)
                        }
                        .environmentObject(viewModel)
                        
                        // Heart Rate card
                        MetricGraphCard(metric: .heartRate) {
                            HeartRateGraphView(heartRateHistory: viewModel.heartRateHistory)
                        }
                        .environmentObject(viewModel)
                        
                        // SpO2 card
                        MetricGraphCard(metric: .spo2) {
                            SpO2GraphView(spo2History: viewModel.spo2History)
                        }
                        .environmentObject(viewModel)
                        
                        // Temperature card
                        MetricGraphCard(metric: .temperature) {
                            TemperatureGraphView(temperatureHistory: viewModel.temperatureHistory)
                        }
                        .environmentObject(viewModel)
                        
                        // Accelerometer card
                        MetricGraphCard(metric: .accelerometer) {
                            AccelerometerGraphView(accelerometerHistory: viewModel.accelerometerHistory)
                        }
                        .environmentObject(viewModel)
                        
                        // PPG card (last - most technical)
                        MetricGraphCard(metric: .ppg) {
                            PPGGraphView(ppgHistory: viewModel.ppgHistory)
                        }
                        .environmentObject(viewModel)
                    }
                } else {
                    // No Data State
                    NoDataView(isViewerMode: isViewerMode)
                }
            }
            .padding(DesignSystem.Layout.edgePadding)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(DesignSystem.Layout.isIPad ? .inline : .large)
        .background(DesignSystem.Colors.backgroundSecondary.ignoresSafeArea())
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
        } else if let boolValue = value as? Bool {
            return boolValue ? "Yes" : "No"
        } else {
            return "\(value)"
        }
    }
}

// MARK: - Connection Status Card

struct ConnectionStatusCard: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Connection Icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: DesignSystem.Sizing.Icon.md))
                        .foregroundColor(statusColor)
                }
                
                // Connection Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(viewModel.connectionStatus)
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(viewModel.deviceName)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Quick Action Button
                if !viewModel.isConnected {
                    Button(action: {
                        viewModel.toggleScanning()
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                                .font(.system(size: DesignSystem.Sizing.Icon.sm))
                            
                            Text(viewModel.isScanning ? "Stop" : "Scan")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.backgroundTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
            }
            
            // Battery and Connection Quality
            if viewModel.isConnected {
                Divider()
                
                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Battery
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: batteryIcon)
                            .font(.system(size: DesignSystem.Sizing.Icon.sm))
                            .foregroundColor(batteryColor)
                        
                        Text(viewModel.batteryPercentageText)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.md)
    }
    
    private var statusColor: Color {
        if viewModel.isConnected {
            return .green
        } else if viewModel.isScanning {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var statusIcon: String {
        if viewModel.isConnected {
            return "checkmark.circle.fill"
        } else if viewModel.isScanning {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "circle.slash"
        }
    }
    
    private var batteryIcon: String {
        let level = viewModel.batteryLevel
        if level > 75 {
            return "battery.100"
        } else if level > 50 {
            return "battery.75"
        } else if level > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    private var batteryColor: Color {
        let level = viewModel.batteryLevel
        if level > 20 {
            return .green
        } else if level > 10 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - No Data View

struct NoDataView: View {
    let isViewerMode: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: isViewerMode ? "eye.slash" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(isViewerMode ? "No Data in Viewer Mode" : "No Device Connected")
                    .font(DesignSystem.Typography.h3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(isViewerMode ? "Connect hardware to see live data" : "Scan for devices to start monitoring")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Metric Graph Card

struct MetricGraphCard<Content: View>: View {
    let metric: MetricType
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: metric.icon)
                    .font(.system(size: DesignSystem.Sizing.Icon.md))
                    .foregroundColor(metric.color)
                
                Text(metric.title)
                    .font(DesignSystem.Typography.h4)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            content
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.backgroundPrimary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .designShadow(DesignSystem.Shadow.md)
    }
}

// MARK: - Metric Type

enum MetricType {
    case battery
    case heartRate
    case spo2
    case temperature
    case accelerometer
    case ppg
    
    var title: String {
        switch self {
        case .battery: return "Battery"
        case .heartRate: return "Heart Rate"
        case .spo2: return "SpO₂"
        case .temperature: return "Temperature"
        case .accelerometer: return "Movement"
        case .ppg: return "PPG Signal"
        }
    }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .heartRate: return "heart.fill"
        case .spo2: return "drop.fill"
        case .temperature: return "thermometer"
        case .accelerometer: return "waveform.path.ecg"
        case .ppg: return "waveform"
        }
    }
    
    var color: Color {
        switch self {
        case .battery: return .green
        case .heartRate: return .red
        case .spo2: return .blue
        case .temperature: return .orange
        case .accelerometer: return .purple
        case .ppg: return .cyan
        }
    }
}

// MARK: - Battery Graph View

struct BatteryGraphView: View {
    let batteryHistory: [BatteryData]
    
    private var recentData: [BatteryData] {
        Array(batteryHistory.suffix(20))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Value
            HStack(alignment: .firstTextBaseline) {
                if let latest = batteryHistory.last {
                    Text("\(latest.percentage)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("%")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart
            if recentData.count >= 2 {
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
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.minute().second())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
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
                    Image(systemName: "battery.100")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No Battery Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Last Update
            if let latest = batteryHistory.last {
                HStack {
                    Spacer()
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Heart Rate Graph View

struct HeartRateGraphView: View {
    let heartRateHistory: [HeartRateData]
    
    private var recentData: [HeartRateData] {
        Array(heartRateHistory.suffix(20))
    }
    
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 40...120 }
        let values = recentData.map { $0.bpm }
        let minValue = values.min() ?? 60
        let maxValue = values.max() ?? 100
        let padding = (maxValue - minValue) * 0.2
        return (minValue - padding)...(maxValue + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Value
            HStack(alignment: .firstTextBaseline) {
                if let latest = heartRateHistory.last {
                    Text(String(format: "%.0f", latest.bpm))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("bpm")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart
            if recentData.count >= 2 {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("HR", measurement.bpm)
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("HR", measurement.bpm)
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
                }
                .chartYScale(domain: yAxisRange)
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
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
                                Text("\(intValue)")
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
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No Heart Rate Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Last Update
            if let latest = heartRateHistory.last {
                HStack {
                    Spacer()
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Temperature Graph View

struct TemperatureGraphView: View {
    let temperatureHistory: [TemperatureData]
    
    private var recentData: [TemperatureData] {
        Array(temperatureHistory.suffix(20))
    }
    
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 35...38 }
        let values = recentData.map { $0.celsius }
        let minValue = values.min() ?? 36.0
        let maxValue = values.max() ?? 37.0
        let padding = (maxValue - minValue) * 0.3
        return (minValue - padding)...(maxValue + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Value
            HStack(alignment: .firstTextBaseline) {
                if let latest = temperatureHistory.last {
                    Text(String(format: "%.1f", latest.celsius))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("°C")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart
            if recentData.count >= 2 {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Temp", measurement.celsius)
                        )
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Temp", measurement.celsius)
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
                }
                .chartYScale(domain: yAxisRange)
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
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
                // Empty state
                VStack {
                    Image(systemName: "thermometer")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No Temperature Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Last Update
            if let latest = temperatureHistory.last {
                HStack {
                    Spacer()
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Accelerometer Graph View

struct AccelerometerGraphView: View {
    let accelerometerHistory: [AccelerometerData]
    
    private var recentData: [AccelerometerData] {
        Array(accelerometerHistory.suffix(20))
    }
    
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return -2...2 }
        let magnitudes = recentData.map { $0.magnitude }
        let maxMagnitude = magnitudes.max() ?? 1.0
        return -maxMagnitude...maxMagnitude
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Value
            HStack(alignment: .firstTextBaseline) {
                if let latest = accelerometerHistory.last {
                    Text(String(format: "%.2f", latest.magnitude))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("g")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart - Show X, Y, Z components
            if recentData.count >= 2 {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("X", measurement.x)
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Y", measurement.y)
                        )
                        .foregroundStyle(Color.green.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Z", measurement.z)
                        )
                        .foregroundStyle(Color.blue.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
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
                                Text(String(format: "%.1f", doubleValue))
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
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No Movement Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Legend and Last Update
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 6, height: 6)
                    Text("X")
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 6, height: 6)
                    Text("Y")
                    Circle().fill(Color.blue.opacity(0.7)).frame(width: 6, height: 6)
                    Text("Z")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                Spacer()
                
                if let latest = accelerometerHistory.last {
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - PPG Graph View

struct PPGGraphView: View {
    let ppgHistory: [PPGData]
    
    private var recentData: [PPGData] {
        Array(ppgHistory.suffix(20))
    }
    
    private var yAxisRange: ClosedRange<Int> {
        guard !recentData.isEmpty else { return 0...100000 }
        let allValues = recentData.flatMap { [$0.ir, $0.red, $0.green] }
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 100000
        let padding = (maxValue - minValue) / 5
        return (minValue - padding)...(maxValue + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Values
            HStack(alignment: .firstTextBaseline) {
                if let latest = ppgHistory.last {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                            Text("\(latest.red)")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.cyan.opacity(0.7)).frame(width: 8, height: 8)
                            Text("\(latest.ir)")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.green.opacity(0.7)).frame(width: 8, height: 8)
                            Text("\(latest.green)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Chart - Show IR, Red, Green channels
            if recentData.count >= 2 {
                Chart {
                    ForEach(Array(recentData.enumerated()), id: \.offset) { index, measurement in
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("IR", measurement.ir)
                        )
                        .foregroundStyle(Color.cyan.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Red", measurement.red)
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        
                        LineMark(
                            x: .value("Time", measurement.timestamp),
                            y: .value("Green", measurement.green)
                        )
                        .foregroundStyle(Color.green.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartYScale(domain: yAxisRange)
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
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
                                Text("\(intValue / 1000)k")
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
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No PPG Data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Legend and Last Update
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Color.cyan.opacity(0.7)).frame(width: 6, height: 6)
                    Text("IR")
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 6, height: 6)
                    Text("Red")
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 6, height: 6)
                    Text("Green")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                Spacer()
                
                if let latest = ppgHistory.last {
                    Text("Updated \(timeAgo(latest.timestamp))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - SpO2 Graph View

struct SpO2GraphView: View {
    let spo2History: [SpO2Data]
    
    private var recentData: [SpO2Data] {
        Array(spo2History.suffix(20))
    }
    
    private var yAxisRange: ClosedRange<Double> {
        guard !recentData.isEmpty else { return 90...100 }
        let values = recentData.map { $0.percentage }
        let minValue = values.min() ?? 95.0
        let maxValue = values.max() ?? 100.0
        let padding = (maxValue - minValue) * 0.2
        return max(85, minValue - padding)...min(100, maxValue + padding)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Current Value and Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let latest = spo2History.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.0f", latest.percentage))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
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
            if recentData.count >= 2 {
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
                .chartXScale(domain: Date().addingTimeInterval(-60)...Date())
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
        // Create a mock DashboardViewModel for preview
        DashboardView(viewModel: DashboardViewModel.mock())
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
