//
//  DashboardView.swift
//  OralableApp
//
//  Apple Health Style Dashboard - V1 Minimal
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
    @EnvironmentObject var deviceManager: DeviceManager  // ADD THIS LINE

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
                    // Connection readiness indicator - UPDATED
                    connectionReadinessIndicator(viewModel: viewModel)

                    // Muscle Activity - Primary card
                    NavigationLink(destination: LazyView(
                        HistoricalView(
                            metricType: "Muscle Activity",
                            historicalDataManager: dependencies.historicalDataManager
                        )
                        .environmentObject(designSystem)
                        .environmentObject(dependencies.historicalDataManager)
                        .environmentObject(dependencies.sensorDataProcessor)
                    )) {
                        HealthMetricCard(
                            icon: "waveform.path.ecg",
                            title: "Muscle Activity",
                            value: viewModel.muscleActivity > 0 ? String(format: "%.0f", viewModel.muscleActivity) : "N/A",
                            unit: "",
                            color: .purple,
                            sparklineData: viewModel.muscleActivityHistory,
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Movement card - shows numeric value with color coding
                    // Blue = still (low variability), Green = active (high variability)
                    // Sparkline colors individual points based on deviation from mean
                    NavigationLink(destination: LazyView(
                        HistoricalView(
                            metricType: "Movement",
                            historicalDataManager: dependencies.historicalDataManager
                        )
                        .environmentObject(designSystem)
                        .environmentObject(dependencies.historicalDataManager)
                        .environmentObject(dependencies.sensorDataProcessor)
                    )) {
                        MovementMetricCard(
                            value: viewModel.isConnected ? formatMovementValue(viewModel.movementVariability) : "N/A",
                            unit: viewModel.isConnected ? (viewModel.isMoving ? "Active" : "Still") : "",
                            isActive: viewModel.isMoving,
                            isConnected: viewModel.isConnected,
                            sparklineData: Array(viewModel.accelerometerData.suffix(20)),
                            threshold: ThresholdSettings.shared.movementThreshold,
                            showChevron: true
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Heart Rate card
                    NavigationLink(destination: LazyView(
                        HistoricalView(
                            metricType: "Heart Rate",
                            historicalDataManager: dependencies.historicalDataManager
                        )
                        .environmentObject(designSystem)
                        .environmentObject(dependencies.historicalDataManager)
                        .environmentObject(dependencies.sensorDataProcessor)
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

                    // Accelerometer (g-units) card
                    AccelerometerCardView(
                        xRaw: viewModel.isConnected ? viewModel.accelXRaw : 0,
                        yRaw: viewModel.isConnected ? viewModel.accelYRaw : 0,
                        zRaw: viewModel.isConnected ? viewModel.accelZRaw : 0,
                        showChevron: false
                    )

                    // Battery and Temperature side by side
                    HStack(spacing: 12) {
                        HealthMetricCard(
                            icon: batteryIcon(level: viewModel.batteryLevel, charging: viewModel.isCharging),
                            title: "Battery",
                            value: viewModel.batteryLevel > 0 ? "\(Int(viewModel.batteryLevel))" : "N/A",
                            unit: viewModel.batteryLevel > 0 ? "%" : "",
                            color: batteryColor(level: viewModel.batteryLevel),
                            sparklineData: [],
                            showChevron: false
                        )

                        HealthMetricCard(
                            icon: "thermometer",
                            title: "Temperature",
                            value: viewModel.temperature > 0 ? String(format: "%.1f", viewModel.temperature) : "N/A",
                            unit: viewModel.temperature > 0 ? "°C" : "",
                            color: .orange,
                            sparklineData: [],
                            showChevron: false
                        )
                    }

                    // Recording Button
                    RecordingButton(
                        isRecording: viewModel.isRecording,
                        isConnected: viewModel.isConnected,
                        duration: viewModel.formattedDuration,
                        action: { viewModel.toggleRecording() }
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 20)
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

    // MARK: - Connection Readiness Indicator - UPDATED
    private func connectionReadinessIndicator(viewModel: DashboardViewModel) -> some View {
        HStack(spacing: 8) {
            // Status dot with readiness color
            Circle()
                .fill(readinessColor)
                .frame(width: 10, height: 10)

            // Display readiness text
            Text(deviceManager.primaryDeviceReadiness.displayText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // Show device name if connected
            if deviceManager.primaryDeviceReadiness.isConnected {
                Text("•")
                    .foregroundColor(.secondary)
                Text(viewModel.deviceName.isEmpty ? "Device" : viewModel.deviceName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Connect button only if disconnected
            if !viewModel.isConnected {
                Button(action: { viewModel.startScanning() }) {
                    Text("Connect")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - Helper Functions
    
    private var readinessColor: Color {
        switch deviceManager.primaryDeviceReadiness {
        case .ready:
            return .green
        case .failed:
            return .red
        case .disconnected:
            return .gray
        default:
            return .orange
        }
    }
    
    private func batteryIcon(level: Double, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(level: Double) -> Color {
        if level < 20 { return .red }
        if level < 50 { return .orange }
        return .green
    }

    /// Format movement value for display
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
                Image(systemName: "figure.walk")
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

// ==============================================================================
// MARK: - V2 FEATURES (Commented out for future use)
// ==============================================================================

/*
// (keeping all your V2 commented code as-is)
*/
