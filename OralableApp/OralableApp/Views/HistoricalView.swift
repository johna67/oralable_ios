//
//  HistoricalView.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  HistoricalView.swift
//  OralableApp
//
//  Created: November 7, 2025
//  Uses HistoricalViewModel (MVVM pattern)
//

import SwiftUI
import Charts

struct HistoricalView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var historicalDataManager: HistoricalDataManager
    @EnvironmentObject var bleManager: OralableBLE
    @StateObject private var viewModel: HistoricalViewModel
    @State private var selectedDataPoint: HistoricalDataPoint?
    @State private var showingExportSheet = false
    @State private var showingDatePicker = false

    // Navigation state variables (matching DashboardView)
    @State private var showingProfile = false
    @State private var showingDevices = false
    @State private var showingSettings = false
    
    init() {
        // Initialize the view model with the required dependency
        // Note: We can't access @EnvironmentObject in init, so we use a workaround
        let manager = HistoricalDataManager.shared
        _viewModel = StateObject(wrappedValue: HistoricalViewModel(historicalDataManager: manager))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: designSystem.spacing.lg) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Date Range Display
                    dateRangeCard
                    
                    // Summary Metrics
                    if viewModel.hasCurrentMetrics {
                        summaryMetricsGrid
                        
                        // Charts Section
                        chartsSection
                        
                        // Detailed Stats
                        if viewModel.showDetailedStats {
                            detailedStatsSection
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(designSystem.spacing.md)
            }
            .navigationTitle("Historical Data")
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
                        Button(action: { showingDevices = true }) {
                            Image(systemName: "cpu")
                                .font(.system(size: 20))
                                .foregroundColor(designSystem.colors.textPrimary)
                        }

                        Menu {
                            Button(action: { viewModel.refresh() }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }

                            Button(action: { showingExportSheet = true }) {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }

                            Button(action: { viewModel.toggleDetailedStats() }) {
                                Label(
                                    viewModel.showDetailedStats ? "Hide Details" : "Show Details",
                                    systemImage: "chart.bar.doc.horizontal"
                                )
                            }

                            Button(action: { showingSettings = true }) {
                                Label("Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshAsync()
            }
        }
        .onAppear {
            viewModel.updateAllMetrics()
        }
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
        .sheet(isPresented: $showingExportSheet) {
            SharingView()
                .environmentObject(designSystem)
                .environmentObject(AppStateManager.shared)
        }
        .sheet(item: $selectedDataPoint) { dataPoint in
            DataPointDetailView(dataPoint: dataPoint, viewModel: viewModel)
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        VStack(spacing: designSystem.spacing.sm) {
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                Text("Day").tag(TimeRange.day)
                Text("Week").tag(TimeRange.week)
                Text("Month").tag(TimeRange.month)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.selectedTimeRange) { _ in
                viewModel.updateCurrentRangeMetrics()
            }
            
            // Navigation Arrows
            HStack {
                Button(action: { viewModel.selectPreviousTimeRange() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(designSystem.cornerRadius.sm)
                }
                
                Spacer()
                
                Text(viewModel.timeRangeText)
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                Button(action: { viewModel.selectNextTimeRange() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .background(designSystem.colors.backgroundTertiary)
                        .cornerRadius(designSystem.cornerRadius.sm)
                }
                .disabled(viewModel.isCurrentTimeRange)
            }
            .foregroundColor(designSystem.colors.textPrimary)
        }
    }
    
    // MARK: - Date Range Card
    
    private var dateRangeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.dateRangeText)
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Text("Updated \(viewModel.lastUpdateText)")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingDatePicker = true }) {
                Image(systemName: "calendar")
                    .foregroundColor(designSystem.colors.textPrimary)
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Summary Metrics Grid
    
    private var summaryMetricsGrid: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Summary", icon: "chart.bar")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: designSystem.spacing.md) {
                // Heart Rate
                MetricCard(
                    icon: "heart.fill",
                    title: "Avg Heart Rate",
                    value: viewModel.averageHeartRateText,
                    unit: "BPM",
                    color: .red,
                    designSystem: designSystem
                )
                
                // SpO2
                MetricCard(
                    icon: "lungs.fill",
                    title: "Avg SpO2",
                    value: viewModel.averageSpO2Text,
                    unit: "%",
                    color: .blue,
                    designSystem: designSystem
                )
                
                // Temperature
                MetricCard(
                    icon: "thermometer",
                    title: "Avg Temperature",
                    value: viewModel.averageTemperatureText,
                    unit: "°C",
                    color: .orange,
                    designSystem: designSystem
                )
                
                // Activity
                MetricCard(
                    icon: "figure.walk",
                    title: "Active Time",
                    value: viewModel.activeTimeText,
                    unit: "",
                    color: .green,
                    designSystem: designSystem
                )
                
                // Battery Usage
                MetricCard(
                    icon: "battery.75",
                    title: "Avg Battery",
                    value: viewModel.averageBatteryText,
                    unit: "%",
                    color: .yellow,
                    designSystem: designSystem
                )
                
                // Data Points
                MetricCard(
                    icon: "circle.grid.3x3.fill",
                    title: "Data Points",
                    value: viewModel.dataPointsCountText,
                    unit: "",
                    color: .purple,
                    designSystem: designSystem
                )
            }
        }
    }
    
    // MARK: - Charts Section
    
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.lg) {
            SectionHeaderView(title: "Trends", icon: "chart.line.uptrend.xyaxis")
            
            // Heart Rate Chart
            chartCard(
                title: "Heart Rate",
                data: viewModel.heartRateChartData,
                color: .red,
                unit: "BPM"
            )
            
            // SpO2 Chart
            chartCard(
                title: "SpO2",
                data: viewModel.spo2ChartData,
                color: .blue,
                unit: "%"
            )
            
            // Temperature Chart
            chartCard(
                title: "Temperature",
                data: viewModel.temperatureChartData,
                color: .orange,
                unit: "°C"
            )
            
            // Activity Chart
            if !viewModel.activityChartData.isEmpty {
                activityChartCard
            }
        }
    }
    
    // MARK: - Chart Card Component
    
    private func chartCard(title: String, data: [ChartDataPoint], color: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            HStack {
                Text(title)
                    .font(designSystem.typography.headline)
                    .foregroundColor(designSystem.colors.textPrimary)
                
                Spacer()
                
                Text(unit)
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textSecondary)
            }
            
            if data.isEmpty {
                RoundedRectangle(cornerRadius: designSystem.cornerRadius.sm)
                    .fill(designSystem.colors.backgroundTertiary)
                    .frame(height: 150)
                    .overlay(
                        Text("No data available")
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textTertiary)
                    )
            } else {
                Chart(data) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color.gradient.opacity(0.1))
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .onTapGesture { location in
                    // Handle tap to show data point details
                    if let nearestPoint = findNearestDataPoint(at: location, in: data),
                       let metrics = viewModel.currentMetrics {
                        // Find the corresponding full data point
                        if let fullDataPoint = metrics.dataPoints.first(where: { 
                            abs($0.timestamp.timeIntervalSince(nearestPoint.timestamp)) < 60 
                        }) {
                            selectedDataPoint = fullDataPoint
                        }
                    }
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Activity Chart Card
    
    private var activityChartCard: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.sm) {
            Text("Activity Level")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)
            
            Chart(viewModel.activityChartData) { dataPoint in
                BarMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("Activity", dataPoint.value)
                )
                .foregroundStyle(Color.green.gradient)
            }
            .frame(height: 100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding(designSystem.spacing.md)
        .background(designSystem.colors.backgroundSecondary)
        .cornerRadius(designSystem.cornerRadius.md)
    }
    
    // MARK: - Detailed Stats Section
    
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: designSystem.spacing.md) {
            SectionHeaderView(title: "Detailed Statistics", icon: "list.bullet.rectangle")
            
            VStack(spacing: designSystem.spacing.sm) {
                // Heart Rate Stats
                StatsRow(
                    label: "Heart Rate Range",
                    value: "\(viewModel.minHeartRate) - \(viewModel.maxHeartRate) BPM"
                )
                
                // SpO2 Stats
                StatsRow(
                    label: "SpO2 Range",
                    value: "\(viewModel.minSpO2)% - \(viewModel.maxSpO2)%"
                )
                
                // Temperature Stats
                StatsRow(
                    label: "Temperature Range",
                    value: String(format: "%.1f°C - %.1f°C", viewModel.minTemperature, viewModel.maxTemperature)
                )
                
                // Session Info
                StatsRow(
                    label: "Total Sessions",
                    value: viewModel.totalSessionsText
                )
                
                StatsRow(
                    label: "Total Duration",
                    value: viewModel.totalDurationText
                )
                
                StatsRow(
                    label: "Data Quality",
                    value: viewModel.dataQualityText
                )
            }
            .padding(designSystem.spacing.md)
            .background(designSystem.colors.backgroundSecondary)
            .cornerRadius(designSystem.cornerRadius.md)
        }
    }
    
    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: designSystem.spacing.lg) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundColor(designSystem.colors.textTertiary)

            Text("No Historical Data")
                .font(designSystem.typography.headline)
                .foregroundColor(designSystem.colors.textPrimary)

            VStack(spacing: designSystem.spacing.sm) {
                Text("Connect your Oralable device to start collecting data")
                    .font(designSystem.typography.body)
                    .foregroundColor(designSystem.colors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Data recording starts automatically when your device connects")
                    .font(designSystem.typography.caption)
                    .foregroundColor(designSystem.colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            // Show connection status
            if !bleManager.isConnected {
                Button(action: {
                    // Navigate to devices view to connect
                }) {
                    HStack {
                        Image(systemName: "sensor.fill")
                        Text("Go to Devices")
                    }
                    .padding(designSystem.spacing.md)
                    .background(designSystem.colors.primaryBlack)
                    .foregroundColor(designSystem.colors.primaryWhite)
                    .cornerRadius(designSystem.cornerRadius.md)
                }
            } else {
                HStack(spacing: designSystem.spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Device connected - collecting data...")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
            }
        }
        .padding(designSystem.spacing.xl)
    }
    
    // MARK: - Helper Methods
    
    private func findNearestDataPoint(at location: CGPoint, in data: [ChartDataPoint]) -> ChartDataPoint? {
        // Implementation to find the nearest data point based on tap location
        // This is a simplified version
        return data.first
    }
}

// MARK: - Stats Row Component

struct StatsRow: View {
    @EnvironmentObject var designSystem: DesignSystem
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
            Spacer()
            Text(value)
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textPrimary)
        }
    }
}

// MARK: - Data Point Detail View

struct DataPointDetailView: View {
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    
    let dataPoint: HistoricalDataPoint
    let viewModel: HistoricalViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section("Timestamp") {
                    HStack {
                        Text("Date")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(dataPoint.timestamp.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    HStack {
                        Text("Time")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(dataPoint.timestamp.formatted(date: .omitted, time: .standard))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                }
                
                Section("Metrics") {
                    if let heartRate = dataPoint.averageHeartRate {
                        HStack {
                            Text("Heart Rate")
                                .foregroundColor(designSystem.colors.textSecondary)
                            Spacer()
                            Text("\(Int(heartRate)) BPM")
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                    if let spo2 = dataPoint.averageSpO2 {
                        HStack {
                            Text("SpO2")
                                .foregroundColor(designSystem.colors.textSecondary)
                            Spacer()
                            Text("\(Int(spo2))%")
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                    HStack {
                        Text("Temperature")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.1f°C", dataPoint.averageTemperature))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    HStack {
                        Text("Battery")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text("\(dataPoint.averageBattery)%")
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    HStack {
                        Text("Movement Intensity")
                            .foregroundColor(designSystem.colors.textSecondary)
                        Spacer()
                        Text(String(format: "%.2f", dataPoint.movementIntensity))
                            .foregroundColor(designSystem.colors.textPrimary)
                    }
                    if let grindingEvents = dataPoint.grindingEvents {
                        HStack {
                            Text("Grinding Events")
                                .foregroundColor(designSystem.colors.textSecondary)
                            Spacer()
                            Text("\(grindingEvents)")
                                .foregroundColor(designSystem.colors.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Data Point Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct HistoricalView_Previews: PreviewProvider {
    static var previews: some View {
        HistoricalView()
            .environmentObject(DesignSystem.shared)
    }
}
