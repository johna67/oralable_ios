//
//  HistoricalDataView.swift
//  OralableApp
//
//  Updated to support both Viewer and Subscription modes
//

import SwiftUI
import Charts

struct HistoricalDataView: View {
    @ObservedObject var ble: OralableBLE
    var isViewerMode: Bool = false  // NEW: Flag to indicate Viewer Mode
    @StateObject private var historyManager: HistoricalDataManager
    @State private var selectedRange: TimeRange = .day
    @State private var showExportSheet = false
    
    init(ble: OralableBLE, isViewerMode: Bool = false) {
        self.ble = ble
        self.isViewerMode = isViewerMode
        _historyManager = StateObject(wrappedValue: HistoricalDataManager(bleManager: ble))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Viewer Mode Notice (if applicable and no data)
                    if isViewerMode && (historyManager.getMetrics(for: selectedRange)?.totalSamples ?? 0) == 0 {
                        viewerModeNotice
                    }
                    
                    // Time Range Picker
                    timeRangePicker
                    
                    // Main Content
                    if let metrics = historyManager.getMetrics(for: selectedRange) {
                        if metrics.totalSamples > 0 {
                            // Summary Cards
                            summaryCards(metrics: metrics)
                            
                            // Temperature Chart
                            temperatureChart(metrics: metrics)
                            
                            // Battery Chart
                            batteryChart(metrics: metrics)
                            
                            // Activity Summary
                            activitySummary(metrics: metrics)
                            
                            // Trends
                            trendsSection(metrics: metrics)
                        } else {
                            noDataView
                        }
                    } else {
                        loadingView
                    }
                }
                .padding()
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { historyManager.updateMetrics(for: selectedRange) }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: { showExportSheet = true }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
        }
        .onAppear {
            historyManager.startAutoUpdate()
        }
        .onDisappear {
            historyManager.stopAutoUpdate()
        }
    }
    
    // MARK: - Viewer Mode Notice
    
    private var viewerModeNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Historical Data in Viewer Mode")
                .font(.headline)
            
            Text("Import data files to view historical trends and statistics. Connect device in Subscription Mode for live data collection.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .onChange(of: selectedRange) { newValue in
            historyManager.updateMetrics(for: newValue)
        }
    }
    
    // MARK: - Summary Cards
    
    private func summaryCards(metrics: HistoricalMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HistoryStatCard(
                title: "Total Samples",
                value: "\(metrics.totalSamples)",
                icon: "chart.bar.fill",
                color: Color.blue
            )
            
            HistoryStatCard(
                title: "Avg Temperature",
                value: String(format: "%.1f°C", metrics.avgTemperature),
                icon: "thermometer.medium",
                color: Color.orange
            )
            
            HistoryStatCard(
                title: "Avg Battery",
                value: String(format: "%.0f%%", metrics.avgBatteryLevel),
                icon: "battery.75",
                color: Color.green
            )
            
            HistoryStatCard(
                title: "Grinding Events",
                value: "\(metrics.totalGrindingEvents)",
                icon: "exclamationmark.triangle.fill",
                color: Color.red
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Temperature Chart
    
    private func temperatureChart(metrics: HistoricalMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(metrics.dataPoints.enumerated()), id: \.offset) { index, point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Temperature", point.avgTemperature)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                Text("Temperature: \(String(format: "%.1f°C", metrics.avgTemperature))")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Battery Chart
    
    private func batteryChart(metrics: HistoricalMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Battery Level Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(metrics.dataPoints.enumerated()), id: \.offset) { index, point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Battery", point.avgBatteryLevel)
                        )
                        .foregroundStyle(.green)
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                Text("Battery: \(String(format: "%.0f%%", metrics.avgBatteryLevel))")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Activity Summary
    
    private func activitySummary(metrics: HistoricalMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Summary")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                HistoryActivityRow(
                    label: "Grinding Events",
                    value: "\(metrics.totalGrindingEvents)",
                    icon: "exclamationmark.triangle.fill"
                )
                
                HistoryActivityRow(
                    label: "Total Duration",
                    value: formatDuration(metrics.totalGrindingDuration),
                    icon: "clock.fill"
                )
                
                HistoryActivityRow(
                    label: "Data Points",
                    value: "\(metrics.dataPoints.count)",
                    icon: "point.3.connected.trianglepath.dotted"
                )
                
                HistoryActivityRow(
                    label: "Time Range",
                    value: "\(selectedRange.rawValue)",
                    icon: "calendar"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Trends Section
    
    private func trendsSection(metrics: HistoricalMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                HistoryTrendRow(label: "Temperature", trend: metrics.temperatureTrend)
                HistoryTrendRow(label: "Battery", trend: metrics.batteryTrend)
                HistoryTrendRow(label: "Activity", trend: metrics.activityTrend)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading historical data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }
    
    // MARK: - No Data View
    
    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Data Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(isViewerMode ?
                "Import data files to view historical trends." :
                "Start recording data to see historical trends and statistics.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .padding()
    }
    
    // MARK: - Export Sheet
    
    private var exportSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export historical data as JSON file")
                    .foregroundColor(.secondary)
                
                Button(action: exportData) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func exportData() {
        guard let url = ble.exportAndSaveMetrics(for: selectedRange) else {
            return
        }
        
        // Share the file
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        
        showExportSheet = false
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

private struct HistoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct HistoryActivityRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.blue)
                .frame(width: 30)
            
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

private struct HistoryTrendRow: View {
    let label: String
    let trend: Double
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: trendIcon)
                .foregroundColor(trendColor)
            Text(trendText)
                .font(.caption)
                .foregroundColor(trendColor)
        }
    }
    
    private var trendIcon: String {
        if abs(trend) < 0.1 { return "arrow.right" }
        return trend > 0 ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var trendColor: Color {
        if abs(trend) < 0.1 { return Color.gray }
        return trend > 0 ? Color.green : Color.red
    }
    
    private var trendText: String {
        if abs(trend) < 0.1 { return "Stable" }
        return trend > 0 ? "Increasing" : "Decreasing"
    }
}

// MARK: - Preview

#Preview {
    HistoricalDataView(ble: OralableBLE())
}
