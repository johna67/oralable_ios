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
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var bleManager = DeviceManager.shared
    @EnvironmentObject var designSystem: DesignSystem
    
    // NAVIGATION STATE VARIABLES
    @State private var showingProfile = false
    @State private var showingDevices = false
    @State private var showingSettings = false
    @State private var showingHistorical = false
    @State private var showingShare = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Connection Status Card
                    connectionStatusCard
                    
                    // MAM State Card - NEW
                    if bleManager.isConnected {
                        mamStateCard
                    }
                    
                    // Metrics Grid
                    metricsGrid
                    
                    // Waveform Section
                    if bleManager.isConnected {
                        waveformSection
                    }
                    
                    // Action Buttons
                    actionButtons
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
                    .environmentObject(AuthenticationManager.shared)
                    .environmentObject(SubscriptionManager.shared)
            }
            .sheet(isPresented: $showingDevices) {
                DevicesView()
                    .environmentObject(designSystem)
                    .environmentObject(bleManager)
                    .environmentObject(DeviceManager.shared)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(designSystem)
                    .environmentObject(AuthenticationManager.shared)
                    .environmentObject(SubscriptionManager.shared)
                    .environmentObject(AppStateManager.shared)
            }
            .sheet(isPresented: $showingHistorical) {
                HistoricalView()
                    .environmentObject(designSystem)
                    .environmentObject(HistoricalDataManager.shared)
                    .environmentObject(bleManager)
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
    
    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        VStack(spacing: designSystem.spacing.md) {
            HStack {
                // Status Icon
                Image(systemName: bleManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(bleManager.isConnected ? .green : .red)
                
                // Status Text
                VStack(alignment: .leading) {
                    Text(bleManager.isConnected ? "Connected" : "Disconnected")
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                    
                    if bleManager.isConnected {
                        Text(bleManager.deviceName)
                            .font(designSystem.typography.caption)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Connect Button
                Button(action: {
                    if bleManager.isConnected {
                        bleManager.disconnect()
                    } else {
                        bleManager.startScanning()
                    }
                }) {
                    Text(bleManager.isConnected ? "Disconnect" : "Connect")
                        .font(designSystem.typography.button)
                        .foregroundColor(.white)
                        .padding(.horizontal, designSystem.spacing.md)
                        .padding(.vertical, designSystem.spacing.sm)
                        .background(bleManager.isConnected ? Color.red : Color.blue)
                        .cornerRadius(designSystem.cornerRadius.medium)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - MAM State Card (NEW)
    private var mamStateCard: some View {
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
                    Image(systemName: positionQualityIcon)
                        .font(.system(size: 28))
                        .foregroundColor(positionQualityColor)
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
    
    private var positionQualityIcon: String {
        switch viewModel.positionQuality {
        case "Good": return "checkmark.circle.fill"
        case "Adjust": return "exclamationmark.triangle.fill"
        default: return "xmark.circle.fill"
        }
    }
    
    private var positionQualityColor: Color {
        switch viewModel.positionQuality {
        case "Good": return .green
        case "Adjust": return .orange
        default: return .red
        }
    }
    
    // MARK: - Metrics Grid
    private var metricsGrid: some View {
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
                icon: batteryIcon,
                title: "Battery",
                value: "\(Int(bleManager.batteryLevel))",
                unit: "%",
                color: batteryColor,
                designSystem: designSystem
            )
            
            // Session Time
            MetricCard(
                icon: "clock.fill",
                title: "Session",
                value: viewModel.sessionDuration,
                unit: "",
                color: .purple,
                designSystem: designSystem
            )
            
            // Signal Quality
            MetricCard(
                icon: "wifi",
                title: "Signal",
                value: "\(viewModel.signalQuality)",
                unit: "%",
                color: .green,
                designSystem: designSystem
            )
        }
    }
    
    private var batteryIcon: String {
        if viewModel.isCharging {
            return "battery.100.bolt"
        }
        let level = bleManager.batteryLevel
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }
    
    private var batteryColor: Color {
        let level = bleManager.batteryLevel
        if level < 20 { return .red }
        if level < 50 { return .orange }
        return .green
    }
    
    // MARK: - Waveform Section
    private var waveformSection: some View {
        VStack(spacing: designSystem.spacing.md) {
            // PPG Waveform
            WaveformCard(
                title: "PPG Signal",
                data: viewModel.ppgData,
                color: .red,
                designSystem: designSystem
            )
            
            // Accelerometer
            WaveformCard(
                title: "Movement",
                data: viewModel.accelerometerData,
                color: .blue,
                designSystem: designSystem
            )
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: designSystem.spacing.md) {
            // Historical Data
            Button(action: { showingHistorical = true }) {
                Label("History", systemImage: "chart.line.uptrend.xyaxis")
                    .font(designSystem.typography.button)
                    .foregroundColor(designSystem.colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.backgroundSecondary)
                    .cornerRadius(designSystem.cornerRadius.medium)
            }
            
            // Share
            Button(action: { showingShare = true }) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(designSystem.typography.button)
                    .foregroundColor(designSystem.colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.backgroundSecondary)
                    .cornerRadius(designSystem.cornerRadius.medium)
            }
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
            .environmentObject(DesignSystem.shared)
    }
}
