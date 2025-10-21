// MARK: - Historical Data Aggregation System - Usage Examples
//
// This file demonstrates how to use the historical data aggregation system
// in your views and view models.
//
// FILES ADDED IN STEP 2:
// 1. OralableBLE+HistoricalData.swift - Extension methods for OralableBLE
// 2. HistoricalDataManager.swift - Manager for caching metrics
//
// PREREQUISITE FROM STEP 1:
// - HistoricalDataModels.swift - Data models and aggregator

import SwiftUI

// MARK: - Example 1: Basic Usage in a View

struct HistoricalDataExampleView: View {
    @ObservedObject var ble: OralableBLE
    @State private var selectedRange: TimeRange = .day
    @State private var metrics: HistoricalMetrics?
    
    var body: some View {
        VStack {
            // Time range picker
            Picker("Time Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedRange) { _, newValue in
                // Load metrics when range changes
                metrics = ble.getHistoricalMetrics(for: newValue)
            }
            
            // Display metrics
            if let metrics = metrics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics for \(metrics.timeRange)")
                        .font(.headline)
                    
                    Text("Samples: \(metrics.totalSamples)")
                    Text("Avg Temperature: \(String(format: "%.1f°C", metrics.avgTemperature))")
                    Text("Avg Battery: \(String(format: "%.0f%%", metrics.avgBatteryLevel))")
                    Text("Grinding Events: \(metrics.totalGrindingEvents)")
                }
                .padding()
            } else {
                Text("No data available for this range")
            }
        }
        .onAppear {
            // Load initial metrics
            metrics = ble.getHistoricalMetrics(for: selectedRange)
        }
    }
}

// MARK: - Example 2: Using HistoricalDataManager (Recommended)

struct HistoricalDataWithManagerView: View {
    @ObservedObject var ble: OralableBLE
    @StateObject private var historyManager: HistoricalDataManager
    @State private var selectedRange: TimeRange = .day
    
    init(ble: OralableBLE) {
        self.ble = ble
        _historyManager = StateObject(wrappedValue: HistoricalDataManager(bleManager: ble))
    }
    
    var body: some View {
        VStack {
            // Range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Display cached metrics
            if let metrics = historyManager.getMetrics(for: selectedRange) {
                MetricsDisplayView(metrics: metrics)
            } else {
                ProgressView("Loading...")
            }
            
            // Update button
            Button("Refresh") {
                historyManager.updateMetrics(for: selectedRange)
            }
        }
        .onAppear {
            // Start auto-updates when view appears
            historyManager.startAutoUpdate()
        }
        .onDisappear {
            // Stop auto-updates to save resources
            historyManager.stopAutoUpdate()
        }
    }
}

// MARK: - Example 3: Checking Data Availability

struct DataAvailabilityView: View {
    @ObservedObject var ble: OralableBLE
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Availability")
                .font(.headline)
            
            // Overall summary
            Text(ble.getDataAvailabilitySummary())
                .font(.subheadline)
            
            // Check each range
            ForEach(TimeRange.allCases, id: \.self) { range in
                HStack {
                    Text(range.rawValue)
                    Spacer()
                    Image(systemName: ble.hasDataForRange(range) ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(ble.hasDataForRange(range) ? .green : .red)
                }
            }
            
            // Data collection rate
            Text("Collection Rate: \(String(format: "%.1f", ble.getDataCollectionRate())) samples/min")
                .font(.caption)
        }
        .padding()
    }
}

// MARK: - Example 4: Displaying Metrics with Chart

struct MetricsDisplayView: View {
    let metrics: HistoricalMetrics
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary Statistics
                summarySection
                
                // Trends
                trendsSection
                
                // Data Points (for charting)
                dataPointsSection
            }
            .padding()
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            
            HStack {
                StatCard(title: "Total Samples", value: "\(metrics.totalSamples)")
                StatCard(title: "Avg Temp", value: String(format: "%.1f°C", metrics.avgTemperature))
            }
            
            HStack {
                StatCard(title: "Avg Battery", value: String(format: "%.0f%%", metrics.avgBatteryLevel))
                StatCard(title: "Grinding Events", value: "\(metrics.totalGrindingEvents)")
            }
        }
    }
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trends")
                .font(.headline)
            
            TrendRow(label: "Temperature", trend: metrics.temperatureTrend)
            TrendRow(label: "Battery", trend: metrics.batteryTrend)
            TrendRow(label: "Activity", trend: metrics.activityTrend)
        }
    }
    
    private var dataPointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Points: \(metrics.dataPoints.count)")
                .font(.headline)
            
            // This is where you would add a Chart in the next step
            Text("Chart will be added in Step 3")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Helper Views

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TrendRow: View {
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
        }
    }
    
    private var trendIcon: String {
        if abs(trend) < 0.1 { return "arrow.right" }
        return trend > 0 ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var trendColor: Color {
        if abs(trend) < 0.1 { return .gray }
        return trend > 0 ? .green : .red
    }
    
    private var trendText: String {
        if abs(trend) < 0.1 { return "Stable" }
        return trend > 0 ? "Increasing" : "Decreasing"
    }
}

// MARK: - Example 5: Exporting Historical Data

extension OralableBLE {
    
    /// Example function to export and save historical metrics
    func exportAndSaveMetrics(for range: TimeRange) -> URL? {
        guard let jsonData = exportHistoricalMetrics(for: range) else {
            return nil
        }
        
        let fileName = "oralable_metrics_\(range.rawValue.lowercased())_\(Int(Date().timeIntervalSince1970)).json"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving metrics: \(error)")
            return nil
        }
    }
}

// MARK: - Testing/Debugging Helpers

extension OralableBLE {
    
    /// Generate mock historical data for testing (call this in debug builds only)
    func generateMockHistoricalData(hours: Int = 24) {
        let now = Date()
        let intervalBetweenSamples: TimeInterval = 60.0 // 1 sample per minute
        let totalSamples = hours * 60
        
        for i in 0..<totalSamples {
            var mockData = SensorData()
            mockData.timestamp = now.addingTimeInterval(-Double(totalSamples - i) * intervalBetweenSamples)
            
            // Generate some varying data
            mockData.temperature = 36.5 + Double.random(in: -0.5...0.5)
            mockData.batteryVoltage = Int32(3800 - (i * 2))
            mockData.ppg.samples = [PPGSample(
                red: UInt32.random(in: 50000...100000),
                ir: UInt32.random(in: 50000...100000),
                green: UInt32.random(in: 50000...100000),
                timestamp: mockData.timestamp
            )]
            
            historicalData.append(mockData)
        }
        
        addLog("Generated \(totalSamples) mock samples for testing", level: .info)
    }
}

// MARK: - USAGE INSTRUCTIONS
/*
 
 TO INTEGRATE THESE FILES INTO YOUR PROJECT:
 
 1. Add all three files to your Xcode project:
    - HistoricalDataModels.swift (from Step 1)
    - OralableBLE+HistoricalData.swift (this step)
    - HistoricalDataManager.swift (this step)
 
 2. In your existing views, you can now:
    a. Call ble.getHistoricalMetrics(for: .day) to get day metrics
    b. Or use HistoricalDataManager for automatic caching and updates
 
 3. The HistoricalDataManager is recommended because:
    - It caches results (faster UI)
    - Auto-updates periodically
    - Prevents blocking the main thread
 
 4. For testing, you can generate mock data:
    ble.generateMockHistoricalData(hours: 24)
 
 NEXT STEPS (Step 3):
 - Create the HistoricalDataView with time period selector
 - Add SwiftUI Charts to visualize the data points
 - Style it similar to Withings app
 
 */
