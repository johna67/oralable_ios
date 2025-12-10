//
//  DashboardView.swift
//  OralableApp
//
//  Apple Health Style Dashboard - V1 Minimal
//  Updated: December 8, 2025 - Added Movement to connection indicator, show g-units
//

import SwiftUI
import Charts

// MARK: - LazyView Helper
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct DashboardView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var deviceManagerAdapter: DeviceManagerAdapter
    @EnvironmentObject var deviceManager: DeviceManager
    @ObservedObject private var featureFlags = FeatureFlags.shared

    @State private var viewModel: DashboardViewModel?
    @State private var showingProfile = false

    var body: some View {
        Group {
            if let vm = viewModel {
                dashboardContent(viewModel: vm)
            } else {
                ProgressView("Loading...")
                    .task {
                        if viewModel == nil {
                            viewModel = dependencies.makeDashboardViewModel()
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func dashboardContent(viewModel: DashboardViewModel) -> some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Dual device connection status indicator (now includes Movement)
                    deviceStatusIndicator(viewModel: viewModel)

                    // Recording Button - at top for easy access
                    RecordingButton(
                        isRecording: viewModel.isRecording,
                        isConnected: viewModel.isConnected,
                        duration: viewModel.formattedDuration,
                        action: { viewModel.toggleRecording() }
                    )
                    .padding(.vertical, 8)

                    // PPG Card (Oralable) - Shows IR sensor data
                    NavigationLink(destination: LazyView(
                        HistoricalView(metricType: "IR Activity")
                            .environmentObject(designSystem)
                            .environmentObject(dependencies.recordingSessionManager)
                    )) {
                        HealthMetricCard(
                            icon: "waveform.path.ecg",
                            title: "PPG Sensor",
                            value: viewModel.oralableConnected ? String(format: "%.0f", max(0, viewModel.ppgIRValue)) : "N/A",
                            unit: viewModel.oralableConnected ? "Oralable IR" : "Not Connected",
                            color: .purple,
                            sparklineData: viewModel.ppgHistory,
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // EMG Card (ANR M40) - Shows EMG muscle activity
                    NavigationLink(destination: LazyView(
                        HistoricalView(metricType: "EMG Activity")
                            .environmentObject(designSystem)
                            .environmentObject(dependencies.recordingSessionManager)
                    )) {
                        HealthMetricCard(
                            icon: "bolt.fill",
                            title: "EMG Sensor",
                            value: viewModel.anrConnected ? String(format: "%.0f", max(0, viewModel.emgValue)) : "N/A",
                            unit: viewModel.anrConnected ? "ANR M40 µV" : "Not Connected",
                            color: .blue,
                            sparklineData: viewModel.emgHistory,
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Movement card - CONDITIONAL - Now shows g-units
                    if featureFlags.showMovementCard {
                        NavigationLink(destination: LazyView(
                            HistoricalView(metricType: "Movement")
                                .environmentObject(designSystem)
                                .environmentObject(dependencies.recordingSessionManager)
                        )) {
                            MovementMetricCard(
                                value: viewModel.isConnected ? formatMovementInG(viewModel: viewModel) : "N/A",
                                unit: viewModel.isConnected ? "g" : "",
                                statusText: viewModel.isConnected ? (viewModel.isMoving ? "Active" : "Still") : "Not Connected",
                                isActive: viewModel.isMoving,
                                isConnected: viewModel.isConnected,
                                sparklineData: Array(viewModel.accelerometerData.suffix(20)),
                                threshold: ThresholdSettings.shared.movementThreshold,
                                showChevron: true
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Heart Rate card - CONDITIONAL
                    if featureFlags.showHeartRateCard {
                        NavigationLink(destination: LazyView(
                            HistoricalView(metricType: "Heart Rate")
                                .environmentObject(designSystem)
                                .environmentObject(dependencies.recordingSessionManager)
                        )) {
                            HealthMetricCard(
                                icon: "heart.fill",
                                title: "Heart Rate",
                                value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "N/A",
                                unit: viewModel.heartRate > 0 ? "BPM" : "",
                                color: .red,
                                sparklineData: [],
                                showChevron: true
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // SpO2 card - CONDITIONAL
                    if featureFlags.showSpO2Card {
                        NavigationLink(destination: LazyView(
                            HistoricalView(metricType: "SpO2")
                                .environmentObject(designSystem)
                                .environmentObject(dependencies.recordingSessionManager)
                        )) {
                            HealthMetricCard(
                                icon: "lungs.fill",
                                title: "Blood Oxygen",
                                value: viewModel.spO2 > 0 ? "\(viewModel.spO2)" : "N/A",
                                unit: viewModel.spO2 > 0 ? "%" : "",
                                color: .cyan,
                                sparklineData: [],
                                showChevron: true
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Temperature card - CONDITIONAL (with history navigation)
                    if featureFlags.showTemperatureCard {
                        NavigationLink(destination: LazyView(
                            HistoricalView(metricType: "Temperature")
                                .environmentObject(designSystem)
                                .environmentObject(dependencies.recordingSessionManager)
                        )) {
                            HealthMetricCard(
                                icon: "thermometer",
                                title: "Temperature",
                                value: viewModel.temperature > 0 ? String(format: "%.1f", viewModel.temperature) : "N/A",
                                unit: viewModel.temperature > 0 ? "°C" : "",
                                color: .orange,
                                sparklineData: [],
                                showChevron: true
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Battery card - CONDITIONAL (no history)
                    if featureFlags.showBatteryCard {
                        HealthMetricCard(
                            icon: batteryIcon(level: viewModel.batteryLevel, charging: viewModel.isCharging),
                            title: "Battery",
                            value: viewModel.batteryLevel > 0 ? "\(Int(viewModel.batteryLevel))" : "N/A",
                            unit: viewModel.batteryLevel > 0 ? "%" : "",
                            color: batteryColor(level: viewModel.batteryLevel),
                            sparklineData: [],
                            showChevron: false
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
                    .environmentObject(designSystem)
                    .environmentObject(dependencies.authenticationManager)
                    .environmentObject(dependencies.subscriptionManager)
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    // MARK: - Device Status Indicator (PPG, EMG, Movement)
    private func deviceStatusIndicator(viewModel: DashboardViewModel) -> some View {
        // Get per-device battery levels
        let oralableBattery = SensorDataProcessor.shared.getBatteryLevel(for: .oralable)
        let anrBattery = SensorDataProcessor.shared.getBatteryLevel(for: .anr)
        
        return VStack(spacing: 6) {
            // Oralable (PPG) status row with battery
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.oralableConnected ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                Text("PPG")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple)
                    .cornerRadius(4)
                
                Text("Oralable")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Battery indicator for Oralable
                if viewModel.oralableConnected && oralableBattery >= 0 {
                    HStack(spacing: 2) {
                        Image(systemName: batteryIconSmall(level: oralableBattery))
                            .font(.system(size: 12))
                            .foregroundColor(batteryColor(level: oralableBattery))
                        Text("\(Int(oralableBattery))%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(viewModel.oralableConnected ? "Ready" : "Not Connected")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.oralableConnected ? .green : .secondary)
            }
            
            // ANR M40 (EMG) status row with battery (N/A)
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.anrConnected ? Color.green : (viewModel.anrFailed ? Color.red : Color.gray))
                    .frame(width: 10, height: 10)
                
                Text("EMG")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
                
                Text("ANR M40")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Battery indicator for ANR - show N/A (battery < 0 means not available)
                if viewModel.anrConnected {
                    HStack(spacing: 2) {
                        Image(systemName: "battery.0")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(anrBattery >= 0 ? "\(Int(anrBattery))%" : "N/A")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(viewModel.anrConnected ? "Ready" : (viewModel.anrFailed ? "Failed" : "Not Connected"))
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.anrConnected ? .green : (viewModel.anrFailed ? .red : .secondary))
            }
            
            // Movement (Accelerometer) status row - data from Oralable device
            HStack(spacing: 8) {
                Circle()
                    .fill(hasAccelerometerData(viewModel: viewModel) ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                Text("MOVE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
                
                Text("Oralable")
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Battery indicator for Oralable (same device as PPG)
                if viewModel.oralableConnected && oralableBattery >= 0 {
                    HStack(spacing: 2) {
                        Image(systemName: batteryIconSmall(level: oralableBattery))
                            .font(.system(size: 12))
                            .foregroundColor(batteryColor(level: oralableBattery))
                        Text("\(Int(oralableBattery))%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status: Match PPG row logic - "Not Connected" when Oralable disconnected
                Text(viewModel.oralableConnected ? (hasAccelerometerData(viewModel: viewModel) ? "Ready" : "No Data") : "Not Connected")
                    .font(.system(size: 12))
                    .foregroundColor(hasAccelerometerData(viewModel: viewModel) ? .green : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
    
    /// Small battery icon for status indicator
    private func batteryIconSmall(level: Double) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        if level > 0 { return "battery.25" }
        return "battery.0"
    }
    
    /// Check if we have accelerometer data (any axis non-zero)
    private func hasAccelerometerData(viewModel: DashboardViewModel) -> Bool {
        return viewModel.isConnected && (viewModel.accelXRaw != 0 || viewModel.accelYRaw != 0 || viewModel.accelZRaw != 0)
    }

    // MARK: - Helper Functions
    
    private func batteryIcon(level: Double, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        if level <= 0 { return "battery.0" }  // N/A or unavailable
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(level: Double) -> Color {
        if level <= 0 { return .gray }  // N/A or unavailable
        if level < 20 { return .red }
        if level < 50 { return .orange }
        return .green
    }

    /// Calculate and format movement magnitude in g-units
    /// Raw accelerometer values are in LSB units (±2g range = 16384 LSB/g)
    private func formatMovementInG(viewModel: DashboardViewModel) -> String {
        let x = Double(viewModel.accelXRaw)
        let y = Double(viewModel.accelYRaw)
        let z = Double(viewModel.accelZRaw)
        
        // Calculate magnitude and convert to g-units
        // LIS2DTW12 at ±2g has 16384 LSB/g sensitivity
        let magnitude = sqrt(x*x + y*y + z*z) / 16384.0
        
        return String(format: "%.2f", magnitude)
    }

    /// Format movement value for display (legacy - used for variability)
    /// Shows values in K notation for large numbers (e.g., 1.5K instead of 1500)
    private func formatMovementValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Health Metric Card (Apple Health Style)
struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    let sparklineData: [Double]
    let showChevron: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: icon, title, chevron
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            // Value row with optional sparkline
            HStack(alignment: .bottom) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Mini sparkline
                if !sparklineData.isEmpty {
                    MiniSparkline(data: sparklineData, color: color)
                        .frame(width: 50, height: 30)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Movement Metric Card (with threshold-colored sparkline)
struct MovementMetricCard: View {
    let value: String
    let unit: String
    let statusText: String  // "Active", "Still", or "Not Connected"
    let isActive: Bool
    let isConnected: Bool
    let sparklineData: [Double]
    let threshold: Double
    let showChevron: Bool

    private var color: Color {
        guard isConnected else { return .gray }
        return isActive ? .green : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: icon, title, chevron
            HStack {
                Image(systemName: "gyroscope")
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text("Movement")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            // Value row with movement sparkline
            HStack(alignment: .bottom) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    
                    // Status indicator (Active/Still/Not Connected)
                    Text(statusText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isConnected ? (isActive ? .green : .blue) : .secondary)
                        .padding(.leading, 8)
                }

                Spacer()

                // Movement sparkline with per-point coloring
                if !sparklineData.isEmpty && isConnected {
                    MovementSparkline(
                        data: sparklineData,
                        threshold: threshold,
                        isOverallActive: isActive,
                        activeColor: .green,
                        stillColor: .blue
                    )
                    .frame(width: 50, height: 30)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Mini Sparkline Chart
struct MiniSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Chart(Array(data.enumerated()), id: \.offset) { index, value in
            LineMark(
                x: .value("Index", index),
                y: .value("Value", value)
            )
            .foregroundStyle(color.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Movement Sparkline with Threshold Coloring
/// Sparkline that colors all points based on overall movement state
/// Green when actively moving, blue when still
struct MovementSparkline: View {
    let data: [Double]
    let threshold: Double  // Movement variability threshold from settings (500-5000)
    let isOverallActive: Bool  // Whether the overall state is "Active" (variability > threshold)
    let activeColor: Color
    let stillColor: Color

    var body: some View {
        // All points use the same color based on overall active/still state
        let pointColor = isOverallActive ? activeColor.opacity(0.8) : stillColor.opacity(0.6)

        Chart(Array(data.enumerated()), id: \.offset) { index, value in
            PointMark(
                x: .value("Index", index),
                y: .value("Value", value)
            )
            .foregroundStyle(pointColor)
            .symbolSize(10)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

// MARK: - Recording Button
struct RecordingButton: View {
    let isRecording: Bool
    let isConnected: Bool
    let duration: String
    let action: () -> Void

    private var buttonColor: Color {
        if !isConnected { return .gray }
        return isRecording ? .red : .black
    }

    private var iconName: String {
        isRecording ? "stop.fill" : "circle.fill"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 70, height: 70)
                        .shadow(color: buttonColor.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: iconName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                if isRecording {
                    Text(duration)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Text(isConnected ? "Record" : "Not Connected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isConnected ? .primary : .secondary)
                }
            }
        }
        .disabled(!isConnected)
        .opacity(isConnected ? 1.0 : 0.5)
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        let appState = AppStateManager()
        let healthKit = HealthKitManager()
        let sensorStore = SensorDataStore()
        let recordingSession = RecordingSessionManager()
        let historicalData = HistoricalDataManager(sensorDataProcessor: SensorDataProcessor.shared)
        let authManager = AuthenticationManager()
        let subscription = SubscriptionManager()
        let device = DeviceManager()
        let sharedData = SharedDataManager(
            authenticationManager: authManager,
            healthKitManager: healthKit,
            sensorDataProcessor: SensorDataProcessor.shared
        )

        let dependencies = AppDependencies(
            authenticationManager: authManager,
            healthKitManager: healthKit,
            recordingSessionManager: recordingSession,
            historicalDataManager: historicalData,
            sensorDataStore: sensorStore,
            subscriptionManager: subscription,
            deviceManager: device,
            sensorDataProcessor: SensorDataProcessor.shared,
            appStateManager: appState,
            sharedDataManager: sharedData,
            designSystem: designSystem
        )

        return DashboardView()
            .withDependencies(dependencies)
            .environmentObject(designSystem)
    }
}
