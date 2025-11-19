//
//  DashboardView.swift
//  OralableApp
//
//  COMPLETE VERSION WITH NAVIGATION AND MAM STATES
//  Replace your entire DashboardView.swift with this code
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var bleManager: OralableBLE
    @EnvironmentObject var appStateManager: AppStateManager

    // Create viewModel from dependencies on first appear
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
                        // Initialize viewModel from dependencies
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
                    // Connection Status Card
                    connectionStatusCard(viewModel: viewModel)

                    // HealthKit Integration Card
                    if healthKitManager.isAvailable {
                        HealthKitIntegrationCard()
                    }

                    // MAM State Card
                    if viewModel.isConnected {
                        mamStateCard(viewModel: viewModel)
                    }

                    // Metrics Grid
                    metricsGrid(viewModel: viewModel)

                    // Waveform Section
                    if viewModel.isConnected {
                        waveformSection(viewModel: viewModel)
                    }
                }
                .padding(designSystem.spacing.md)
            }
            .background(designSystem.colors.backgroundPrimary)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            // NAVIGATION TOOLBAR - CRITICAL FIX
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
                        // Share button - smart sync with dentist
                        Button(action: {
                            Task {
                                await self.handleSmartShare()
                            }
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
            // SHEET PRESENTATIONS
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
                SettingsView()
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
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Smart Share

    /// Intelligently handles data sharing with dentist
    /// - If recording: stops, uploads, restarts
    /// - If not recording: just uploads available data
    private func handleSmartShare() async {
        Logger.shared.info("[DashboardView] Smart share initiated")

        let wasRecording = self.bleManager.isRecording

        if wasRecording {
            Logger.shared.info("[DashboardView] Recording active - stopping to upload")
            // Stop current recording (this triggers CloudKit upload automatically)
            self.bleManager.stopRecording()

            // Wait for recording state to actually become false
            // This is necessary because the state update happens via Combine and might not be immediate
            var waitCount = 0
            while self.bleManager.isRecording && waitCount < 10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                waitCount += 1
                Logger.shared.debug("[DashboardView] Waiting for recording to stop... (\(waitCount))")
            }

            if self.bleManager.isRecording {
                Logger.shared.error("[DashboardView] Failed to stop recording - state still shows recording")
                return
            }

            Logger.shared.info("[DashboardView] Recording stopped successfully")

            // Wait a moment for upload to complete
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Restart recording if device is still connected
            if self.bleManager.isConnected {
                Logger.shared.info("[DashboardView] Restarting recording after share")
                self.bleManager.startRecording()

                // Verify recording actually started
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if self.bleManager.isRecording {
                    Logger.shared.info("[DashboardView] ✅ Recording restarted successfully")
                } else {
                    Logger.shared.warning("[DashboardView] ⚠️ Recording restart may have failed")
                }
            }
        } else {
            Logger.shared.info("[DashboardView] No active recording - sharing available sessions")
            // Upload any completed sessions that haven't been uploaded yet
            await uploadPendingSessions()
        }

        Logger.shared.info("[DashboardView] Smart share completed")
    }

    /// Upload any pending recording sessions
    private func uploadPendingSessions() async {
        let sessions = RecordingSessionManager.shared.sessions
        let completedSessions = sessions.filter { $0.status == .completed }

        Logger.shared.info("[DashboardView] Found \(completedSessions.count) completed sessions to potentially upload")

        let sharedDataManager = self.dependencies.sharedDataManager

        // Upload each completed session
        // Note: The uploadRecordingSession method will handle deduplication
        for session in completedSessions {
            do {
                try await sharedDataManager.uploadRecordingSession(session)
                Logger.shared.info("[DashboardView] Uploaded session \(session.id)")
            } catch {
                Logger.shared.error("[DashboardView] Failed to upload session \(session.id): \(error)")
            }
        }
    }

    // MARK: - Connection Status Card
    private func connectionStatusCard(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: designSystem.spacing.md) {
            HStack {
                // Status Icon
                Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(viewModel.isConnected ? .green : .red)

                // Status Text
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

                // Connect Button
                Button(action: {
                    if viewModel.isConnected {
                        viewModel.bleManagerRef.disconnect()
                    } else {
                        viewModel.bleManagerRef.startScanning()
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

    // MARK: - MAM State Card (NEW)
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
            // Heart Rate
            MetricCard(
                icon: "heart.fill",
                title: "Heart Rate",
                value: "\(viewModel.heartRate)",
                unit: "bpm",
                color: .red,
                designSystem: designSystem
            )

            // SpO2
            MetricCard(
                icon: "lungs.fill",
                title: "SpO2",
                value: "\(viewModel.spO2)",
                unit: "%",
                color: .blue,
                designSystem: designSystem
            )

            // Temperature
            MetricCard(
                icon: "thermometer",
                title: "Temperature",
                value: String(format: "%.1f", viewModel.temperature),
                unit: "°C",
                color: .orange,
                designSystem: designSystem
            )

            // Battery
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
        if viewModel.isCharging {
            return "battery.100.bolt"
        }
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
            // PPG Waveform
            WaveformCard(
                title: "PPG Signal",
                data: viewModel.ppgData,
                color: .red,
                designSystem: designSystem
            )

            // Accelerometer - Tappable to view history
            NavigationLink(destination: HistoricalView(metricType: "Movement")
                .environmentObject(designSystem)
                .environmentObject(dependencies.historicalDataManager)
                .environmentObject(bleManager)) {
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
            .environmentObject(DesignSystem())
            .environmentObject(AppDependencies())
            .environmentObject(HealthKitManager())
            .environmentObject(OralableBLE())
    }
}
