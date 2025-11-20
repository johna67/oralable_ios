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
    @Published var hourMetrics: HistoricalMetrics?
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
    
    /// Current offset from present time (0 = current period, -1 = previous period, etc.)
    @Published var timeRangeOffset: Int = 0
    
    // MARK: - Private Properties
    
    private let historicalDataManager: HistoricalDataManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Whether any metrics are available
    var hasAnyMetrics: Bool {
        hourMetrics != nil || dayMetrics != nil || weekMetrics != nil || monthMetrics != nil
    }
    
    /// Whether current metrics are available
    var hasCurrentMetrics: Bool {
        currentMetrics != nil
    }
    
    /// Whether the selected time range is the current period (today/this week/this month)
    var isCurrentTimeRange: Bool {
        timeRangeOffset == 0
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
        if timeRangeOffset == 0 {
            switch selectedTimeRange {
            case .hour: return "This Hour"
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            }
        } else if timeRangeOffset == -1 {
            switch selectedTimeRange {
            case .hour: return "Last Hour"
            case .day: return "Yesterday"
            case .week: return "Last Week"
            case .month: return "Last Month"
            }
        } else {
            let absoluteOffset = abs(timeRangeOffset)
            switch selectedTimeRange {
            case .hour: return "\(absoluteOffset) Hours Ago"
            case .day: return "\(absoluteOffset) Days Ago"
            case .week: return "\(absoluteOffset) Weeks Ago"
            case .month: return "\(absoluteOffset) Months Ago"
            }
        }
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
    
    // MARK: - Metric Text Properties
    
    /// Average heart rate text
    var averageHeartRateText: String {
        guard let metrics = currentMetrics else { return "--" }
        let avgHR = metrics.dataPoints.compactMap { $0.averageHeartRate }.reduce(0, +) / Double(max(metrics.dataPoints.count, 1))
        return avgHR > 0 ? String(format: "%.0f", avgHR) : "--"
    }
    
    /// Average SpO2 text
    var averageSpO2Text: String {
        guard let metrics = currentMetrics else { return "--" }
        let avgSpO2 = metrics.dataPoints.compactMap { $0.averageSpO2 }.reduce(0, +) / Double(max(metrics.dataPoints.count, 1))
        return avgSpO2 > 0 ? String(format: "%.0f", avgSpO2) : "--"
    }
    
    /// Average temperature text
    var averageTemperatureText: String {
        guard let metrics = currentMetrics else { return "--" }
        return String(format: "%.1f", metrics.avgTemperature)
    }
    
    /// Average battery text
    var averageBatteryText: String {
        guard let metrics = currentMetrics else { return "--" }
        return String(format: "%.0f", metrics.avgBatteryLevel)
    }
    
    /// Active time text
    var activeTimeText: String {
        guard let metrics = currentMetrics else { return "--" }
        let totalActivity = metrics.dataPoints.map { $0.movementIntensity }.reduce(0, +)
        let hours = Int(totalActivity)
        let minutes = Int((totalActivity - Double(hours)) * 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    /// Data points count text
    var dataPointsCountText: String {
        guard let metrics = currentMetrics else { return "--" }
        return "\(metrics.dataPoints.count)"
    }
    
    /// Total grinding events text
    var totalGrindingEventsText: String {
        guard let metrics = currentMetrics else { return "--" }
        return "\(metrics.totalGrindingEvents)"
    }
    
    // MARK: - Trend Text Properties (without arrows/symbols)
    
    /// Heart rate trend text
    var heartRateTrendText: String? {
        guard let metrics = currentMetrics else { return nil }
        let heartRates = metrics.dataPoints.compactMap { $0.averageHeartRate }
        guard heartRates.count >= 2 else { return nil }
        
        let firstThird = heartRates.prefix(heartRates.count / 3)
        let lastThird = heartRates.suffix(heartRates.count / 3)
        
        let avgFirst = firstThird.reduce(0, +) / Double(max(firstThird.count, 1))
        let avgLast = lastThird.reduce(0, +) / Double(max(lastThird.count, 1))
        let trend = avgLast - avgFirst
        
        if abs(trend) < 1 { return nil }
        return trend > 0 ? "+\(Int(trend))" : "\(Int(trend))"
    }
    
    /// SpO2 trend text
    var spo2TrendText: String? {
        guard let metrics = currentMetrics else { return nil }
        let spo2Values = metrics.dataPoints.compactMap { $0.averageSpO2 }
        guard spo2Values.count >= 2 else { return nil }
        
        let firstThird = spo2Values.prefix(spo2Values.count / 3)
        let lastThird = spo2Values.suffix(spo2Values.count / 3)
        
        let avgFirst = firstThird.reduce(0, +) / Double(max(firstThird.count, 1))
        let avgLast = lastThird.reduce(0, +) / Double(max(lastThird.count, 1))
        let trend = avgLast - avgFirst
        
        if abs(trend) < 0.5 { return nil }
        return trend > 0 ? "+\(String(format: "%.1f", trend))" : "\(String(format: "%.1f", trend))"
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
    
    // MARK: - Chart Data Properties
    
    /// Heart rate chart data points
    var heartRateChartData: [ChartDataPoint] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.dataPoints.compactMap { point in
            guard let hr = point.averageHeartRate else { return nil }
            return ChartDataPoint(timestamp: point.timestamp, value: hr)
        }
    }
    
    /// SpO2 chart data points
    var spo2ChartData: [ChartDataPoint] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.dataPoints.compactMap { point in
            guard let spo2 = point.averageSpO2 else { return nil }
            return ChartDataPoint(timestamp: point.timestamp, value: spo2)
        }
    }
    
    /// Temperature chart data points
    var temperatureChartData: [ChartDataPoint] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.dataPoints.map { point in
            ChartDataPoint(timestamp: point.timestamp, value: point.averageTemperature)
        }
    }
    
    /// Activity chart data points
    var activityChartData: [ChartDataPoint] {
        guard let metrics = currentMetrics else { return [] }
        return metrics.dataPoints.map { point in
            ChartDataPoint(timestamp: point.timestamp, value: point.movementIntensity)
        }
    }
    
    // MARK: - Detailed Statistics Properties
    
    /// Minimum heart rate
    var minHeartRate: Int {
        guard let metrics = currentMetrics else { return 0 }
        let heartRates = metrics.dataPoints.compactMap { $0.averageHeartRate }
        return Int(heartRates.min() ?? 0)
    }
    
    /// Maximum heart rate
    var maxHeartRate: Int {
        guard let metrics = currentMetrics else { return 0 }
        let heartRates = metrics.dataPoints.compactMap { $0.averageHeartRate }
        return Int(heartRates.max() ?? 0)
    }
    
    /// Minimum SpO2
    var minSpO2: Int {
        guard let metrics = currentMetrics else { return 0 }
        let spo2Values = metrics.dataPoints.compactMap { $0.averageSpO2 }
        return Int(spo2Values.min() ?? 0)
    }
    
    /// Maximum SpO2
    var maxSpO2: Int {
        guard let metrics = currentMetrics else { return 0 }
        let spo2Values = metrics.dataPoints.compactMap { $0.averageSpO2 }
        return Int(spo2Values.max() ?? 0)
    }
    
    /// Minimum temperature
    var minTemperature: Double {
        guard let metrics = currentMetrics else { return 0 }
        let temps = metrics.dataPoints.map { $0.averageTemperature }
        return temps.min() ?? 0
    }
    
    /// Maximum temperature
    var maxTemperature: Double {
        guard let metrics = currentMetrics else { return 0 }
        let temps = metrics.dataPoints.map { $0.averageTemperature }
        return temps.max() ?? 0
    }
    
    /// Total sessions text
    var totalSessionsText: String {
        guard let metrics = currentMetrics else { return "--" }
        return "\(metrics.dataPoints.count)"
    }
    
    /// Total duration text
    var totalDurationText: String {
        guard let metrics = currentMetrics else { return "--" }
        let duration = metrics.endDate.timeIntervalSince(metrics.startDate)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Data quality text (percentage of non-nil values)
    var dataQualityText: String {
        guard let metrics = currentMetrics else { return "--" }
        let totalPoints = metrics.dataPoints.count
        guard totalPoints > 0 else { return "--" }
        
        let validHRCount = metrics.dataPoints.compactMap { $0.averageHeartRate }.count
        let validSpO2Count = metrics.dataPoints.compactMap { $0.averageSpO2 }.count
        let totalValid = validHRCount + validSpO2Count
        let totalPossible = totalPoints * 2
        
        let quality = Double(totalValid) / Double(totalPossible) * 100
        return String(format: "%.0f%%", quality)
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
        Logger.shared.info("[HistoricalViewModel] 🚀 Initializing HistoricalViewModel...")
        self.historicalDataManager = historicalDataManager
        Logger.shared.info("[HistoricalViewModel] Setting up bindings...")
        setupBindings()
        Logger.shared.info("[HistoricalViewModel] Updating current metrics for initial selectedTimeRange: \(selectedTimeRange)")
        updateCurrentMetrics()
        Logger.shared.info("[HistoricalViewModel] ✅ HistoricalViewModel initialization complete")
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Subscribe to selectedTimeRange changes
        $selectedTimeRange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRange in
                Logger.shared.info("[HistoricalViewModel] 📍 Time range changed to: \(newRange)")
                self?.updateCurrentMetrics()
                // Trigger update if we don't have metrics for this range
                let hasMetrics: Bool = {
                    guard let self = self else { return false }
                    switch newRange {
                    case .hour: return self.hourMetrics != nil
                    case .day: return self.dayMetrics != nil
                    case .week: return self.weekMetrics != nil
                    case .month: return self.monthMetrics != nil
                    }
                }()
                if !hasMetrics {
                    Logger.shared.warning("[HistoricalViewModel] ⚠️ No metrics available for \(newRange), requesting update...")
                    self?.historicalDataManager.updateMetrics(for: newRange)
                }
            }
            .store(in: &cancellables)

        // Subscribe to historical data manager's published properties
        historicalDataManager.$hourMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                if let metrics = metrics {
                    Logger.shared.info("[HistoricalViewModel] ✅ Received Hour metrics | Data points: \(metrics.dataPoints.count) | Total samples: \(metrics.totalSamples)")
                } else {
                    Logger.shared.debug("[HistoricalViewModel] Hour metrics cleared (nil)")
                }
                self?.hourMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)

        historicalDataManager.$dayMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                if let metrics = metrics {
                    Logger.shared.info("[HistoricalViewModel] ✅ Received Day metrics | Data points: \(metrics.dataPoints.count) | Total samples: \(metrics.totalSamples)")
                } else {
                    Logger.shared.debug("[HistoricalViewModel] Day metrics cleared (nil)")
                }
                self?.dayMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)

        historicalDataManager.$weekMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                if let metrics = metrics {
                    Logger.shared.info("[HistoricalViewModel] ✅ Received Week metrics | Data points: \(metrics.dataPoints.count) | Total samples: \(metrics.totalSamples)")
                } else {
                    Logger.shared.debug("[HistoricalViewModel] Week metrics cleared (nil)")
                }
                self?.weekMetrics = metrics
                self?.updateCurrentMetricsIfNeeded()
            }
            .store(in: &cancellables)

        historicalDataManager.$monthMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                if let metrics = metrics {
                    Logger.shared.info("[HistoricalViewModel] ✅ Received Month metrics | Data points: \(metrics.dataPoints.count) | Total samples: \(metrics.totalSamples)")
                } else {
                    Logger.shared.debug("[HistoricalViewModel] Month metrics cleared (nil)")
                }
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
            .sink { [weak self] range in
                Logger.shared.debug("[HistoricalViewModel] Time range changed to: \(range)")
                self?.updateCurrentMetrics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods - Data Management

    /// Update all metrics
    func updateAllMetrics() {
        Logger.shared.debug("[HistoricalViewModel] Requesting metrics update from HistoricalDataManager")
        historicalDataManager.updateAllMetrics()
    }

    /// Update metrics for current time range
    func updateCurrentRangeMetrics() {
        Logger.shared.debug("[HistoricalViewModel] Requesting metrics update for range: \(selectedTimeRange)")
        historicalDataManager.updateMetrics(for: selectedTimeRange)
    }

    /// Refresh current view
    func refresh() {
        Logger.shared.info("[HistoricalViewModel] Manual refresh triggered")
        updateCurrentRangeMetrics()
    }
    
    /// Async refresh for SwiftUI refreshable modifier
    func refreshAsync() async {
        refresh()
        // Give a small delay to ensure UI updates properly
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
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
    
    /// Move to next time range (forward in time, toward present)
    func selectNextTimeRange() {
        if timeRangeOffset < 0 {
            timeRangeOffset += 1
            updateCurrentRangeMetrics()
        }
    }
    
    /// Move to previous time range (backward in time)
    func selectPreviousTimeRange() {
        timeRangeOffset -= 1
        updateCurrentRangeMetrics()
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
        Logger.shared.info("[HistoricalViewModel] 🔄 updateCurrentMetrics() called for selectedTimeRange: \(selectedTimeRange)")

        switch selectedTimeRange {
        case .hour:
            Logger.shared.debug("[HistoricalViewModel] Hour case - hourMetrics state: \(hourMetrics == nil ? "NIL" : "EXISTS with \(hourMetrics!.dataPoints.count) points")")
            currentMetrics = hourMetrics
            if let metrics = hourMetrics {
                Logger.shared.info("[HistoricalViewModel] ✅ Current metrics updated to Hour | Data points: \(metrics.dataPoints.count) | Total samples: \(metrics.totalSamples) | Avg temp: \(String(format: "%.1f", metrics.avgTemperature))°C")
                if metrics.dataPoints.isEmpty {
                    Logger.shared.warning("[HistoricalViewModel] ⚠️ Hour metrics exist but dataPoints array is EMPTY!")
                } else {
                    Logger.shared.debug("[HistoricalViewModel] First data point: timestamp=\(metrics.dataPoints[0].timestamp), temp=\(String(format: "%.1f", metrics.dataPoints[0].averageTemperature))°C")
                }
            } else {
                Logger.shared.warning("[HistoricalViewModel] ⚠️ Current metrics cleared - hourMetrics is NIL")
            }
        case .day:
            currentMetrics = dayMetrics
            if let metrics = dayMetrics {
                Logger.shared.info("[HistoricalViewModel] Current metrics updated to Day | \(metrics.dataPoints.count) data points")
            } else {
                Logger.shared.debug("[HistoricalViewModel] Current metrics cleared (no day metrics available)")
            }
        case .week:
            currentMetrics = weekMetrics
            if let metrics = weekMetrics {
                Logger.shared.info("[HistoricalViewModel] Current metrics updated to Week | \(metrics.dataPoints.count) data points")
            } else {
                Logger.shared.debug("[HistoricalViewModel] Current metrics cleared (no week metrics available)")
            }
        case .month:
            currentMetrics = monthMetrics
            if let metrics = monthMetrics {
                Logger.shared.info("[HistoricalViewModel] Current metrics updated to Month | \(metrics.dataPoints.count) data points")
            } else {
                Logger.shared.debug("[HistoricalViewModel] Current metrics cleared (no month metrics available)")
            }
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

// MARK: - Chart Data Point

/// Represents a single point on a chart
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
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
