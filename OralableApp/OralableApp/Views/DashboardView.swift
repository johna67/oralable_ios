//
//  DashboardView.swift
//  OralableApp
//
//  Updated: November 7, 2025
//  Refactored to use DashboardViewModel (MVVM pattern)
//

import SwiftUI
import Charts

struct DashboardView: View {
    // MVVM: Use ViewModel instead of direct manager access
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    
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
                        Button(action: { viewModel.toggleRecording() }) {
                            Label(
                                viewModel.isRecording ? "Stop Recording" : "Start Recording",
                                systemImage: viewModel.isRecording ? "stop.circle" : "record.circle"
                            )
                        }
                        
                        Button(action: { viewModel.exportData() }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { viewModel.refreshData() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.connectionStatus)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                if viewModel.isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if viewModel.isConnected {
                HStack {
                    Label(viewModel.deviceName, systemImage: "dot.radiowaves.left.and.right")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                    
                    Spacer()
                    
                    Label("\(viewModel.batteryLevel)%", systemImage: "battery.\(viewModel.batteryIconName)")
                        .font(designSystem.typography.caption)
                        .foregroundColor(viewModel.batteryColor)
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: designSystem.spacing.md) {
            // Heart Rate
            MetricCard(
                title: "Heart Rate",
                value: viewModel.heartRateText,
                unit: "BPM",
                icon: "heart.fill",
                color: .red,
                trend: viewModel.heartRateTrend
            )
            
            // SpO2
            MetricCard(
                title: "SpO2",
                value: viewModel.spo2Text,
                unit: "%",
                icon: "lungs.fill",
                color: .blue,
                trend: viewModel.spo2Trend
            )
            
            // Temperature
            MetricCard(
                title: "Temperature",
                value: viewModel.temperatureText,
                unit: "°C",
                icon: "thermometer",
                color: .orange,
                trend: viewModel.temperatureTrend
            )
            
            // Activity
            MetricCard(
                title: "Activity",
                value: viewModel.activityLevel,
                unit: "",
                icon: "figure.walk",
                color: .green,
                trend: nil
            )
        }
    }
    
    // MARK: - PPG Waveform Card
    
    private var ppgWaveformCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Text("PPG Signal")
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                Text(viewModel.ppgQualityText)
                    .font(designSystem.typography.caption)
                    .foregroundColor(viewModel.ppgQualityColor)
            }
            
            Chart(viewModel.ppgChartData) { dataPoint in
                LineMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Value", dataPoint.value)
                )
                .foregroundStyle(Color.red.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Accelerometer Card
    
    private var accelerometerCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Text("Movement")
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                Text(viewModel.movementStatusText)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Chart {
                ForEach(viewModel.accelerometerChartData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("X", dataPoint.x)
                    )
                    .foregroundStyle(Color.red)
                    
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Y", dataPoint.y)
                    )
                    .foregroundStyle(Color.green)
                    
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Z", dataPoint.z)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .frame(height: 150)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            
            // Legend
            HStack(spacing: designSystem.spacing.md) {
                Label("X", systemImage: "circle.fill")
                    .foregroundColor(.red)
                    .font(designSystem.typography.caption)
                
                Label("Y", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(designSystem.typography.caption)
                
                Label("Z", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                    .font(designSystem.typography.caption)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Quick Actions Card
    
    private var quickActionsCard: some View {
        VStack(spacing: designSystem.spacing.sm) {
            SectionHeaderView(title: "Quick Actions", icon: "bolt.fill")
            
            HStack(spacing: designSystem.spacing.md) {
                // Connect/Disconnect Button
                Button(action: {
                    if viewModel.isConnected {
                        viewModel.disconnect()
                    } else {
                        viewModel.startScanning()
                    }
                }) {
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: viewModel.isConnected ? "wifi.slash" : "wifi")
                            .font(.title2)
                        Text(viewModel.isConnected ? "Disconnect" : "Connect")
                            .font(designSystem.typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.backgroundTertiary)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                // Export Button
                Button(action: { viewModel.exportData() }) {
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Export")
                            .font(designSystem.typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.backgroundTertiary)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                // Settings Button
                NavigationLink(destination: SettingsView()) {
                    VStack(spacing: designSystem.spacing.xs) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                        Text("Settings")
                            .font(designSystem.typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.backgroundTertiary)
                    .cornerRadius(designSystem.cornerRadius.sm)
                }
            }
            .foregroundColor(designSystem.colors.textPrimary)
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    @EnvironmentObject var designSystem: DesignSystem
    
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let trend: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(designSystem.typography.title2)
                    .foregroundColor(designSystem.colors.textPrimary)
                Text(unit)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            if let trend = trend {
                Text(trend)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(DesignSystem.shared)
    }
}
