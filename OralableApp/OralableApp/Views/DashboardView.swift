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

                    // Movement card
                    NavigationLink(destination: LazyView(
                        HistoricalView(
                            metricType: "Movement",
                            historicalDataManager: dependencies.historicalDataManager
                        )
                        .environmentObject(designSystem)
                        .environmentObject(dependencies.historicalDataManager)
                        .environmentObject(dependencies.sensorDataProcessor)
                    )) {
                        HealthMetricCard(
                            icon: "figure.walk",
                            title: "Movement",
                            value: viewModel.isMoving ? "Active" : "Still",
                            unit: "",
                            color: .blue,
                            sparklineData: viewModel.accelerometerData.suffix(20).map { $0 },
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

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let designSystem = DesignSystem()
        let appState = AppStateManager()
        let ble = OralableBLE()
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
            bleManager: ble,
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
