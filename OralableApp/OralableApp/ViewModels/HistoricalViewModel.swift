//
//  HistoricalViewModel.swift
//  OralableApp
//
//  Created by John A Cogan on 07/11/2025.
//


//
//  HistoricalViewModel.swift
//  OralableApp
//
//  Created: November 7, 2025
//  MVVM Architecture - Historical data management business logic
//

import Foundation
import Combine

@MainActor
class HistoricalViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable by View)
    
    /// Selected time range for viewing data
    @Published var selectedTimeRange: TimeRange = .day
    
    /// Metrics for each time range
    @Published var dayMetrics: HistoricalMetrics?
    @Published var weekMetrics: HistoricalMetrics?
    @Published var monthMetrics: HistoricalMetrics?
    
    /// Current metrics for selected range
    @Published var currentMetrics: HistoricalMetrics?
    
    /// Whether metrics are being updated
    @Published var isUpdating: Bool = false
    
    /// Last update time
    @Published var lastUpdateTime: Date?
    
    /// Whether to show detailed statistics
    @Published var showDetailedStats: Bool = false
    
    /// Selected data point for detail view
    @Published var selectedDataPoint: HistoricalDataPoint?
    
    // MARK: - Private Properties
    
    private let historicalDataManager: HistoricalDataManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Whether any metrics are available
    var hasAnyMetrics: Bool {
        dayMetrics != nil || weekMetrics != nil || monthMetrics != nil
    }
    
    /// Whether current metrics are available
    var hasCurrentMetrics: Bool {
        currentMetrics != nil
    }
    
    /// Total samples for current range
    var totalSamples: Int {
        currentMetrics?.totalSamples ?? 0
    }
    
    /// Data points for current range
    var dataPoints: [HistoricalDataPoint] {
        currentMetrics?.dataPoints ?? []
    }
    
    /// Time range display text
    var timeRangeText: String {
        selectedTimeRange.rawValue
    }
    
    /// Date range text for display
    var dateRangeText: String {
        guard let metrics = currentMetrics else {
            return "No data"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        
        let start = formatter.string(from: metrics.startDate)
        let end = formatter.string(from: metrics.endDate)
        
        return "\(start) - \(end)"
    }
    
    /// Average temperature text
    var averageTemperatureText: String {
        guard let metrics = currentMetrics else { return "--" }
        return String(format: "%.1f°C", metrics.avgTemperature)
    }
    
    /// Average battery text
    var averageBatteryText: String {
        guard let metrics = currentMetrics else { return "--" }
        return String(format: "%.0f%%", metrics.avgBatteryLevel)
    }
    
    /// Total grinding events text
    var totalGrindingEventsText: String {
        guard let metrics = currentMetrics else { return "--" }
        return "\(metrics.totalGrindingEvents)"
    }
    
    /// Temperature trend text
    var temperatureTrendText: String {
        guard let metrics = currentMetrics else { return "No trend" }
        
        if abs(metrics.temperatureTrend) < 0.1 {
            return "Stable"
        } else if metrics.temperatureTrend > 0 {
            return "↑ Increasing"
        } else {
            return "↓ Decreasing"
        }
    }
    
    /// Battery trend text
    var batteryTrendText: String {
        guard let metrics = currentMetrics else { return "No trend" }
        
        if abs(metrics.batteryTrend) < 1 {
            return "Stable"
        } else if metrics.batteryTrend > 0 {
            return "↑ Charging"
        } else {
            return "↓ Draining"
        }
    }
    
    /// Activity trend text
    var activityTrendText: String {
        guard let metrics = currentMetrics else { return "No trend" }
        
        if abs(metrics.activityTrend) < 0.1 {
            return "Stable"
        } else if metrics.activityTrend > 0 {
            return "↑ More Active"
        } else {
            return "↓ Less Active"
        }
    }
    
    /// Time since last update text
    var lastUpdateText: String {
        guard let lastUpdate = lastUpdateTime else {
            return "Never updated"
        }
        
        let interval = Date().timeIntervalSince(lastUpdate)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
    
    // MARK: - Initialization
    
    init(historicalDataManager: HistoricalDataManager) {
        self.historicalDataManager = historicalDataManager
        setupBindings()
        updateCurrentMetrics()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to historical data manager's published properties
        historicalDataManager.$dayMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.dayMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)
        
        historicalDataManager.$weekMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.weekMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)
        
        historicalDataManager.$monthMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.monthMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)
        
        historicalDataManager.$isUpdating
            .receive(on: DispatchQueue.main)
            .assign(to: &$isUpdating)
        
        historicalDataManager.$lastUpdateTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateTime)
        
        // Update current metrics when selected range changes
        $selectedTimeRange
            .sink { [weak self] _ in
                self?.updateCurrentMetrics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Data Management
    
    /// Update all metrics
    func updateAllMetrics() {
        historicalDataManager.updateAllMetrics()
    }
    
    /// Update metrics for current time range
    func updateCurrentRangeMetrics() {
        historicalDataManager.updateMetrics(for: selectedTimeRange)
    }
    
    /// Refresh current view
    func refresh() {
        updateCurrentRangeMetrics()
    }
    
    /// Clear all cached metrics
    func clearAllMetrics() {
        historicalDataManager.clearAllMetrics()
        currentMetrics = nil
    }
    
    /// Start automatic updates
    func startAutoUpdate() {
        historicalDataManager.startAutoUpdate()
    }
    
    /// Stop automatic updates
    func stopAutoUpdate() {
        historicalDataManager.stopAutoUpdate()
    }
    
    // MARK: - Public Methods - Time Range Selection
    
    /// Select a specific time range
    func selectTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
    }
    
    /// Cycle to next time range
    func selectNextTimeRange() {
        let ranges: [TimeRange] = [.day, .week, .month]
        if let currentIndex = ranges.firstIndex(of: selectedTimeRange) {
            let nextIndex = (currentIndex + 1) % ranges.count
            selectedTimeRange = ranges[nextIndex]
        }
    }
    
    /// Cycle to previous time range
    func selectPreviousTimeRange() {
        let ranges: [TimeRange] = [.day, .week, .month]
        if let currentIndex = ranges.firstIndex(of: selectedTimeRange) {
            let previousIndex = (currentIndex - 1 + ranges.count) % ranges.count
            selectedTimeRange = ranges[previousIndex]
        }
    }
    
    // MARK: - Public Methods - Data Point Selection
    
    /// Select a data point for detailed view
    func selectDataPoint(_ point: HistoricalDataPoint) {
        selectedDataPoint = point
    }
    
    /// Clear selected data point
    func clearSelectedDataPoint() {
        selectedDataPoint = nil
    }
    
    // MARK: - Public Methods - Display Options
    
    /// Toggle detailed statistics view
    func toggleDetailedStats() {
        showDetailedStats.toggle()
    }
    
    // MARK: - Private Methods
    
    private func updateCurrentMetrics() {
        switch selectedTimeRange {
        case .hour:
            currentMetrics = nil // Hour range not supported
        case .day:
            currentMetrics = dayMetrics
        case .week:
            currentMetrics = weekMetrics
        case .month:
            currentMetrics = monthMetrics
        }
    }
    
    private func updateCurrentMetricsIfNeeded() {
        // Update current metrics if the selected range matches the updated range
        updateCurrentMetrics()
    }
    
    // MARK: - Formatting Helpers
    
    /// Format a data point's timestamp
    func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        switch selectedTimeRange {
        case .hour, .day:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "EEE"
        case .month:
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: date)
    }
    
    /// Format temperature value
    func formatTemperature(_ temp: Double) -> String {
        String(format: "%.1f°C", temp)
    }
    
    /// Format battery value
    func formatBattery(_ battery: Int) -> String {
        "\(battery)%"
    }
    
    /// Format heart rate value
    func formatHeartRate(_ hr: Double?) -> String {
        guard let hr = hr else { return "--" }
        return String(format: "%.0f bpm", hr)
    }
    
    /// Format SpO2 value
    func formatSpO2(_ spo2: Double?) -> String {
        guard let spo2 = spo2 else { return "--" }
        return String(format: "%.0f%%", spo2)
    }
}

// MARK: - Mock for Previews

extension HistoricalViewModel {
    static func mock() -> HistoricalViewModel {
        // Create mock BLE manager and historical data manager
        let mockBLE = OralableBLE.mock()
        let mockHistoricalManager = HistoricalDataManager(bleManager: mockBLE)
        
        let viewModel = HistoricalViewModel(historicalDataManager: mockHistoricalManager)
        
        // Create mock metrics
        let mockDataPoints = (0..<10).map { index in
            HistoricalDataPoint(
                timestamp: Date().addingTimeInterval(TimeInterval(-3600 * index)),
                averageHeartRate: 65.0 + Double.random(in: -5...5),
                heartRateQuality: 0.9,
                averageSpO2: 98.0 + Double.random(in: -2...2),
                spo2Quality: 0.95,
                averageTemperature: 36.5 + Double.random(in: -0.5...0.5),
                averageBattery: 85 - (index * 5),
                movementIntensity: Double.random(in: 0...1),
                grindingEvents: Int.random(in: 0...3)
            )
        }
        
        let mockMetrics = HistoricalMetrics(
            timeRange: "Day",
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date(),
            totalSamples: 1000,
            dataPoints: mockDataPoints,
            temperatureTrend: 0.2,
            batteryTrend: -5.0,
            activityTrend: 0.1,
            avgTemperature: 36.5,
            avgBatteryLevel: 75.0,
            totalGrindingEvents: 5,
            totalGrindingDuration: 300
        )
        
        viewModel.dayMetrics = mockMetrics
        viewModel.currentMetrics = mockMetrics
        
        return viewModel
    }
}
