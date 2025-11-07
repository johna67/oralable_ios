//
//  DashboardView.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Complete MVVM implementation - No duplicate views
//

import SwiftUI
import Charts

struct DashboardView: View {
    // MVVM: Use ViewModel with convenience initializer
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    
    // View State
    @State private var showingExportSheet = false
    @State private var selectedTimeRange: TimeRange = .day
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Connection Status Card
                    connectionStatusCard
                    
                    // Real-time Metrics Grid
                    if viewModel.isConnected {
                        metricsGrid
                        
                        // PPG Waveform Chart
                        if !viewModel.ppgData.isEmpty {
                            ppgWaveformCard
                        }
                        
                        // Accelerometer Chart
                        if !viewModel.accelerometerData.isEmpty {
                            accelerometerCard
                        }
                    }
                    
                    // Quick Actions
                    quickActionsCard
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.refreshScan() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showingExportSheet = true }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { viewModel.toggleRecording() }) {
                            Label(
                                viewModel.isRecording ? "Stop Recording" : "Start Recording",
                                systemImage: viewModel.isRecording ? "stop.circle" : "record.circle"
                            )
                        }
                        
                        Divider()
                        
                        Button(action: { viewModel.resetBLE() }) {
                            Label("Reset Connection", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareView()
            }
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(spacing: designSystem.spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
                    Text("Connection Status")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    
                    Text(viewModel.deviceName)
                        .font(designSystem.typography.h3)
                        .foregroundColor(designSystem.colors.textPrimary)
                    
                    HStack(spacing: designSystem.spacing.xs) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.connectionStatus)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: { viewModel.toggleScanning() }) {
                    HStack {
                        Image(systemName: viewModel.isConnected ? "stop.circle" :
                              (viewModel.isScanning ? "pause.circle" : "play.circle"))
                        Text(viewModel.scanButtonText)
                    }
                    .font(designSystem.typography.button)
                    .foregroundColor(.white)
                    .padding(.horizontal, designSystem.spacing.md)
                    .padding(.vertical, designSystem.spacing.sm)
                    .background(viewModel.isConnected ? Color.red :
                               (viewModel.isScanning ? Color.orange : Color.blue))
                    .cornerRadius(designSystem.cornerRadius.medium)
                }
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.large)
        }
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: designSystem.spacing.md) {
            MetricCard(
                title: "Heart Rate",
                value: viewModel.heartRateText,
                unit: "bpm",
                icon: "heart.fill",
                color: .red
            )
            
            MetricCard(
                title: "SpO₂",
                value: viewModel.spo2Text,
                unit: "%",
                icon: "drop.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Temperature",
                value: viewModel.temperatureText,
                unit: "",
                icon: "thermometer",
                color: .orange
            )
            
            MetricCard(
                title: "Battery",
                value: viewModel.batteryPercentageText,
                unit: "",
                icon: batteryIcon,
                color: batteryColor
            )
        }
    }
    
    // Battery icon helper
    private var batteryIcon: String {
        switch viewModel.batteryLevel {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }
    
    // Battery color helper
    private var batteryColor: Color {
        switch viewModel.batteryLevel {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
    
    // MARK: - PPG Waveform Card
    
    private var ppgWaveformCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Text("PPG Waveform")
                    .font(designSystem.typography.h3)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: designSystem.spacing.xs) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Red")
                        .font(designSystem.typography.caption)
                    
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("IR")
                        .font(designSystem.typography.caption)
                }
                .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Chart(viewModel.ppgData) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Red", dataPoint.red)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("IR", dataPoint.ir)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .frame(height: 200)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Accelerometer Card
    
    private var accelerometerCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Text("Accelerometer")
                    .font(designSystem.typography.h3)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: designSystem.spacing.xs) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("X")
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Y")
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("Z")
                }
                .font(designSystem.typography.caption)
                .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Chart(viewModel.accelerometerData) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("X", dataPoint.x)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Y", dataPoint.y)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Z", dataPoint.z)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .frame(height: 150)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
    
    // MARK: - Quick Actions Card
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Quick Actions")
                .font(designSystem.typography.h3)
                .foregroundColor(designSystem.colors.textPrimary)
            
            HStack(spacing: designSystem.spacing.md) {
                QuickActionButton(
                    title: "Export",
                    icon: "square.and.arrow.up",
                    action: { showingExportSheet = true }
                )
                
                NavigationLink(destination: HistoricalView()) {
                    QuickActionView(
                        title: "History",
                        icon: "clock.arrow.circlepath"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: SettingsView()) {
                    QuickActionView(
                        title: "Settings",
                        icon: "gearshape"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.large)
    }
}

// MARK: - Supporting Views (Keep these as they're used within DashboardView)

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(designSystem.colors.backgroundTertiary)
        .cornerRadius(designSystem.cornerRadius.medium)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: designSystem.spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(designSystem.typography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(designSystem.spacing.sm)
            .foregroundColor(designSystem.colors.textPrimary)
            .background(designSystem.colors.backgroundTertiary)
            .cornerRadius(designSystem.cornerRadius.small)
        }
    }
}

struct QuickActionView: View {
    let title: String
    let icon: String
    @EnvironmentObject var designSystem: DesignSystem
    
    var body: some View {
        VStack(spacing: designSystem.spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(title)
                .font(designSystem.typography.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(designSystem.spacing.sm)
        .foregroundColor(designSystem.colors.textPrimary)
        .background(designSystem.colors.backgroundTertiary)
        .cornerRadius(designSystem.cornerRadius.small)
    }
}

// MARK: - Previews

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(DesignSystem.shared)
    }
}
