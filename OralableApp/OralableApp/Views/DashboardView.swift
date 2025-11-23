//
//  DashboardView.swift
//  OralableApp
//
//  COMPLETE VERSION WITH HISTORY SHORTCUTS
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var appStateManager: AppStateManager

    @State private var viewModel: DashboardViewModel?

    // NAVIGATION STATE VARIABLES
    @State private var showingProfile = false
    @State private var showingDevices = false
    @State private var showingSettings = false
    @State private var showingShare = false
    
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
                VStack(spacing: designSystem.spacing.lg) {
                    connectionStatusCard(viewModel: viewModel)

                    if viewModel.isConnected {
                        mamStateCard(viewModel: viewModel)
                    }

                    metricsGrid(viewModel: viewModel)

                    // History shortcuts
                    historyShortcutSection()

                    if viewModel.isConnected {
                        waveformSection(viewModel: viewModel)
                    }
                }
                .padding(designSystem.spacing.md)
            }
            .background(designSystem.colors.backgroundPrimary)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: designSystem.spacing.sm) {
                        Button(action: {
                            Task { await self.handleSmartShare() }
                        }) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 20))
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                        Button(action: { showingDevices = true }) {
                            Image(systemName: "cpu")
                                .font(.system(size: 20))
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
                    .environmentObject(designSystem)
                    .environmentObject(dependencies.authenticationManager)
                    .environmentObject(dependencies.subscriptionManager)
            }
            .sheet(isPresented: $showingDevices) {
                DevicesView()
                    .environmentObject(designSystem)
                    .environmentObject(bleManager)
                    .environmentObject(dependencies.deviceManager)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: dependencies.makeSettingsViewModel())
                    .environmentObject(dependencies)
                    .environmentObject(designSystem)
                    .environmentObject(dependencies.authenticationManager)
                    .environmentObject(dependencies.subscriptionManager)
                    .environmentObject(dependencies.appStateManager)
            }
            .sheet(isPresented: $showingShare) {
                ShareView(ble: bleManager)
                    .environmentObject(designSystem)
            }
        }
        .onAppear { viewModel.startMonitoring() }
        .onDisappear { viewModel.stopMonitoring() }
    }

    // MARK: - History Shortcut Section
    private func historyShortcutSection() -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            Text("History")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: designSystem.spacing.md) {
                NavigationLink(destination: HistoricalView(
                    metricType: "Movement",
                    historicalDataManager: dependencies.historicalDataManager,
                    bleManager: bleManager
                )
                .environmentObject(designSystem)
                .environmentObject(dependencies.historicalDataManager)
                .environmentObject(bleManager)) {
                    historyCard(title: "Movement", icon: "figure.walk", color: .blue)
                }

                NavigationLink(destination: HistoricalView(
                    metricType: "Heart Rate",
                    historicalDataManager: dependencies.historicalDataManager,
                    bleManager: bleManager
                )
                .environmentObject(designSystem)
                .environmentObject(dependencies.historicalDataManager)
                .environmentObject(bleManager)) {
                    historyCard(title: "Heart Rate", icon: "heart.fill", color: .red)
                }

                NavigationLink(destination: HistoricalView(
                    metricType: "SpO2",
                    historicalDataManager: dependencies.historicalDataManager,
                    bleManager: bleManager
                )
                .environmentObject(designSystem)
                .environmentObject(dependencies.historicalDataManager)
                .environmentObject(bleManager)) {
                    historyCard(title: "SpO2", icon: "lungs.fill", color: .blue)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    private func historyCard(title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                Spacer()
            }
            Text(title)
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textSecondary)
            Text("Tap to view history")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.medium)
    }

    // MARK: - Smart Share
    private func handleSmartShare() async {
        Logger.shared.info("[DashboardView] Smart share initiated")
        let wasRecording = self.bleManager.isRecording

        if wasRecording {
            self.bleManager.stopRecording()
            var waitCount = 0
            while self.bleManager.isRecording && waitCount < 10 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waitCount += 1
            }
            if !self.bleManager.isRecording {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if self.bleManager.isConnected {
                    self.bleManager.startRecording()
                }
            }
        } else {
            await uploadPendingSessions()
        }
        Logger.shared.info("[DashboardView] Smart share completed")
    }

    private func uploadPendingSessions() async {
        let sessions = dependencies.recordingSessionManager.sessions
        let completedSessions = sessions.filter { $0.status == .completed }
        let sharedDataManager = self.dependencies.sharedDataManager

        for session in completedSessions {
            try? await sharedDataManager.uploadRecordingSession(session)
        }
    }

    // MARK: - Connection Status Card
    private func connectionStatusCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: designSystem.spacing.md) {
            HStack {
                Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.isConnected ? .green : .red)

                VStack(alignment: .leading) {
                    Text(viewModel.isConnected ? "Connected" : "Disconnected")
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                    if viewModel.isConnected {
                        Text(viewModel.deviceName)
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }

                Spacer()

                Button(action: {
                    if viewModel.isConnected {
                        viewModel.disconnect()
                    } else {
                        viewModel.startScanning()
                    }
                }) {
                    Text(viewModel.isConnected ? "Disconnect" : "Connect")
                        .font(designSystem.typography.button)
                        .foregroundColor(.white)
                        .padding(.horizontal, designSystem.spacing.md)
                        .padding(.vertical, designSystem.spacing.sm)
                        .background(viewModel.isConnected ? Color.red : Color.blue)
                        .cornerRadius(designSystem.cornerRadius.medium)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }

    // MARK: - MAM State Card
        private func mamStateCard(viewModel: DashboardViewModel) -> some View {
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                Text("MAM STATUS")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
                
                HStack(spacing: 0) {
                    // Charging State
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: viewModel.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.isCharging ? .green : designSystem.colors.textTertiary)
                        Text(viewModel.isCharging ? "Charging" : "Battery")
                            .font(.system(size: 11))
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Movement State
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: viewModel.isMoving ? "figure.walk" : "figure.stand")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.isMoving ? .orange : designSystem.colors.textTertiary)
                        Text(viewModel.isMoving ? "Moving" : "Still")
                            .font(.system(size: 11))
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Position Quality
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: positionQualityIcon(viewModel: viewModel))
                            .font(.system(size: 28))
                            .foregroundColor(positionQualityColor(viewModel: viewModel))
                        Text(viewModel.positionQuality)
                            .font(.system(size: 11))
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.large)
        }

        private func positionQualityIcon(viewModel: DashboardViewModel) -> String {
            switch viewModel.positionQuality {
            case "Good": return "checkmark.circle.fill"
            case "Adjust": return "exclamationmark.triangle.fill"
            default: return "xmark.circle.fill"
            }
        }

        private func positionQualityColor(viewModel: DashboardViewModel) -> Color {
            switch viewModel.positionQuality {
            case "Good": return .green
            case "Adjust": return .orange
            default: return .red
            }
        }

        // MARK: - Metrics Grid
        private func metricsGrid(viewModel: DashboardViewModel) -> some View {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: designSystem.spacing.md) {
                MetricCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: viewModel.heartRate > 0 ? "\(viewModel.heartRate)" : "N/A",
                    unit: "bpm",
                    color: .red,
                    designSystem: designSystem
                )

                MetricCard(
                    icon: "lungs.fill",
                    title: "SpO2",
                    value: viewModel.spO2 > 0 ? "\(viewModel.spO2)" : "N/A",
                    unit: "%",
                    color: .blue,
                    designSystem: designSystem
                )

                MetricCard(
                    icon: "thermometer",
                    title: "Temperature",
                    value: viewModel.temperature > 0 ? String(format: "%.1f", viewModel.temperature) : "N/A",
                    unit: "°C",
                    color: .orange,
                    designSystem: designSystem
                )

                MetricCard(
                    icon: batteryIcon(viewModel: viewModel),
                    title: "Battery",
                    value: "\(Int(viewModel.batteryLevel))",
                    unit: "%",
                    color: batteryColor(viewModel: viewModel),
                    designSystem: designSystem
                )
            }
        }

        private func batteryIcon(viewModel: DashboardViewModel) -> String {
            if viewModel.isCharging { return "battery.100.bolt" }
            let level = viewModel.batteryLevel
            if level > 75 { return "battery.100" }
            if level > 50 { return "battery.75" }
            if level > 25 { return "battery.50" }
            return "battery.25"
        }

        private func batteryColor(viewModel: DashboardViewModel) -> Color {
            let level = viewModel.batteryLevel
            if level < 20 { return .red }
            if level < 50 { return .orange }
            return .green
        }

        // MARK: - Waveform Section
        private func waveformSection(viewModel: DashboardViewModel) -> some View {
            VStack(spacing: designSystem.spacing.md) {
                WaveformCard(
                    title: "PPG Signal",
                    data: viewModel.ppgData,
                    color: .red,
                    designSystem: designSystem
                )

                NavigationLink(
                    destination: HistoricalView(
                        metricType: "Movement",
                        historicalDataManager: dependencies.historicalDataManager,
                        bleManager: bleManager
                    )
                    .environmentObject(designSystem)
                    .environmentObject(dependencies.historicalDataManager)
                    .environmentObject(bleManager)
                ) {
                    WaveformCard(
                        title: "Movement",
                        data: viewModel.accelerometerData,
                        color: .blue,
                        designSystem: designSystem
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Metric Card Component
    struct MetricCard: View {
        let icon: String
        let title: String
        let value: String
        let unit: String
        let color: Color
        let designSystem: DesignSystem
        
        var body: some View {
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 20))
                    Spacer()
                }
                
                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(designSystem.typography.h2)
                        .foregroundColor(designSystem.colors.textPrimary)
                    Text(unit)
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }

    // MARK: - Waveform Card Component
    struct WaveformCard: View {
        let title: String
        let data: [Double]
        let color: Color
        let designSystem: DesignSystem
        
        var body: some View {
            VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
                
                Chart(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                }
                .frame(height: 100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.medium)
        }
    }

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .withDependencies(AppDependencies.shared)
            .environmentObject(DesignSystem())
            .environmentObject(HealthKitManager())
            .environmentObject(OralableBLE())
            .environmentObject(AppStateManager())
    }
}
