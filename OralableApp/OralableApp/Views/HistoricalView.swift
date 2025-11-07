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
    @StateObject private var viewModel = HistoricalViewModel()
    @EnvironmentObject var designSystem: DesignSystem
    @State private var selectedDataPoint: HistoricalDataPoint?
    @State private var showingExportSheet = false
    @State private var showingDatePicker = false
    
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
                    if viewModel.isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
                        
                        if viewModel.isAutoUpdateEnabled {
                            Button(action: { viewModel.stopAutoUpdate() }) {
                                Label("Stop Auto-Update", systemImage: "pause.circle")
                            }
                        } else {
                            Button(action: { viewModel.startAutoUpdate() }) {
                                Label("Start Auto-Update", systemImage: "play.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(designSystem.colors.textPrimary)
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
        .sheet(isPresented: $showingExportSheet) {
            ShareView()
        }
        .sheet(item: $selectedDataPoint) { dataPoint in
            DataPointDetailView(dataPoint: dataPoint, viewModel: viewModel)
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        VStack(spacing: designSystem.spacing.sm) {
            Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                Text("Day").tag(HistoricalViewModel.TimeRange.day)
                Text("Week").tag(HistoricalViewModel.TimeRange.week)
                Text("Month").tag(HistoricalViewModel.TimeRange.month)
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
                
                if let lastUpdate = viewModel.lastUpdateText {
                    Text("Updated \(lastUpdate)")
                        .font(designSystem.typography.caption)
                        .foregroundColor(designSystem.colors.textSecondary)
                }
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
                    title: "Avg Heart Rate",
                    value: viewModel.averageHeartRateText,
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red,
                    trend: viewModel.heartRateTrendText
                )
                
                // SpO2
                MetricCard(
                    title: "Avg SpO2",
                    value: viewModel.averageSpO2Text,
                    unit: "%",
                    icon: "lungs.fill",
                    color: .blue,
                    trend: viewModel.spo2TrendText
                )
                
                // Temperature
                MetricCard(
                    title: "Avg Temperature",
                    value: viewModel.averageTemperatureText,
                    unit: "°C",
                    icon: "thermometer",
                    color: .orange,
                    trend: viewModel.temperatureTrendText
                )
                
                // Activity
                MetricCard(
                    title: "Active Time",
                    value: viewModel.activeTimeText,
                    unit: "",
                    icon: "figure.walk",
                    color: .green,
                    trend: viewModel.activityTrendText
                )
                
                // Battery Usage
                MetricCard(
                    title: "Avg Battery",
                    value: viewModel.averageBatteryText,
                    unit: "%",
                    icon: "battery.75",
                    color: .yellow,
                    trend: viewModel.batteryTrendText
                )
                
                // Data Points
                MetricCard(
                    title: "Data Points",
                    value: viewModel.dataPointsCountText,
                    unit: "",
                    icon: "circle.grid.3x3.fill",
                    color: .purple,
                    trend: nil
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
                    if let dataPoint = findNearestDataPoint(at: location, in: data) {
                        selectedDataPoint = HistoricalDataPoint(
                            timestamp: dataPoint.timestamp,
                            heartRate: title == "Heart Rate" ? Int(dataPoint.value) : nil,
                            spo2: title == "SpO2" ? Int(dataPoint.value) : nil,
                            temperature: title == "Temperature" ? dataPoint.value : nil
                        )
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
            
            Text("Start recording sessions to see your historical data and trends")
                .font(designSystem.typography.body)
                .foregroundColor(designSystem.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                // Navigate to dashboard to start recording
            }) {
                HStack {
                    Image(systemName: "record.circle")
                    Text("Start Recording")
                }
                .padding(designSystem.spacing.md)
                .background(designSystem.colors.primaryBlack)
                .foregroundColor(designSystem.colors.primaryWhite)
                .cornerRadius(designSystem.cornerRadius.md)
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

// MARK: - Chart Data Point

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
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
                    InfoRowView(
                        label: "Date",
                        value: dataPoint.timestamp.formatted(date: .abbreviated, time: .omitted)
                    )
                    InfoRowView(
                        label: "Time",
                        value: dataPoint.timestamp.formatted(date: .omitted, time: .standard)
                    )
                }
                
                Section("Metrics") {
                    if let heartRate = dataPoint.heartRate {
                        InfoRowView(label: "Heart Rate", value: "\(heartRate) BPM")
                    }
                    if let spo2 = dataPoint.spo2 {
                        InfoRowView(label: "SpO2", value: "\(spo2)%")
                    }
                    if let temperature = dataPoint.temperature {
                        InfoRowView(label: "Temperature", value: String(format: "%.1f°C", temperature))
                    }
                    if let batteryLevel = dataPoint.batteryLevel {
                        InfoRowView(label: "Battery", value: "\(batteryLevel)%")
                    }
                }
                
                if let notes = dataPoint.notes {
                    Section("Notes") {
                        Text(notes)
                            .font(designSystem.typography.body)
                            .foregroundColor(designSystem.colors.textPrimary)
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
