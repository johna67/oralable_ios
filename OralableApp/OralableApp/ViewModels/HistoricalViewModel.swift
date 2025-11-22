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
    
    /// Cached data points (debounced / computed off-main then published on main)
    /// Use this in views instead of calling the heavy computed getter repeatedly
    @Published private(set) var cachedDataPoints: [HistoricalDataPoint] = []
    
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

    private let historicalDataManager: HistoricalDataManagerProtocol  // ✅ Now uses protocol for dependency injection
    private var cancellables = Set<AnyCancellable>()
    
    // Internal cancellable for caching datapoints
    private var metricsCacheCancellable: AnyCancellable?
    
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
    
    /// Data points for current range - lightweight getter returning cached points
    var dataPoints: [HistoricalDataPoint] {
        cachedDataPoints
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
    
    // ... other trend/summary properties unchanged (omitted here for brevity) ...
    
    // MARK: - Initialization

    /// Initialize with injected historicalDataManager (preferred)
    /// - Parameter historicalDataManager: Historical data manager conforming to protocol (allows mocking for tests)
    init(historicalDataManager: HistoricalDataManagerProtocol) {
        Logger.shared.info("[HistoricalViewModel] 🚀 Initializing HistoricalViewModel with protocol-based dependency injection...")
        self.historicalDataManager = historicalDataManager
        Logger.shared.info("[HistoricalViewModel] Setting up bindings...")
        setupBindings()
        Logger.shared.info("[HistoricalViewModel] Updating current metrics for initial selectedTimeRange: \(selectedTimeRange)")
        updateCurrentMetrics()
        Logger.shared.info("[HistoricalViewModel] ✅ HistoricalViewModel initialization complete")
    }

    /// Convenience initializer for backward compatibility (uses AppDependencies singleton)
    convenience init() {
        self.init(historicalDataManager: AppDependencies.shared.historicalDataManager)
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

        // Subscribe to historical data manager's published properties (using protocol publishers)
        historicalDataManager.hourMetricsPublisher
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

        historicalDataManager.dayMetricsPublisher
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

        historicalDataManager.weekMetricsPublisher
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

        historicalDataManager.monthMetricsPublisher
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

        historicalDataManager.isUpdatingPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isUpdating)

        historicalDataManager.lastUpdateTimePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateTime)

        // Keep the existing selectedTimeRange sink that updates current metrics
        $selectedTimeRange
            .sink { [weak self] range in
                Logger.shared.debug("[HistoricalViewModel] Time range changed to: \(range)")
                self?.updateCurrentMetrics()
            }
            .store(in: &cancellables)

        // Build a debounced cache pipeline: compute cachedDataPoints off-main then publish on main.
        metricsCacheCancellable = Publishers.CombineLatest($currentMetrics, $selectedTimeRange)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global(qos: .userInitiated))
            .map { (metrics, _) -> [HistoricalDataPoint] in
                return metrics?.dataPoints ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                guard let self = self else { return }
                self.cachedDataPoints = points
                Logger.shared.debug("[HistoricalViewModel] Cached dataPoints updated: \(points.count) points")
            }
    }
    
    // MARK: - Public Methods - Data Management

    /// Update all metrics
    func updateAllMetrics() {
        Logger.shared.info("[HistoricalViewModel] 🔄 Requesting metrics update from HistoricalDataManager")
        Logger.shared.info("[HistoricalViewModel] Current state BEFORE update:")
        Logger.shared.info("[HistoricalViewModel]   - hourMetrics: \(hourMetrics?.dataPoints.count ?? 0) points")
        Logger.shared.info("[HistoricalViewModel]   - dayMetrics: \(dayMetrics?.dataPoints.count ?? 0) points")
        Logger.shared.info("[HistoricalViewModel]   - weekMetrics: \(weekMetrics?.dataPoints.count ?? 0) points")
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
        cachedDataPoints = []
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
    
    /// Toggle detailed statistics view
    func toggleDetailedStats() {
        showDetailedStats.toggle()
    }

    // MARK: - Public Methods - Data Sufficiency

    /// Check if there's sufficient data for the current time range
    var hasSufficientDataForCurrentRange: Bool {
        guard let metrics = currentMetrics else { return false }

        // Need at least 2 data points for a meaningful chart
        guard metrics.dataPoints.count >= 2 else { return false }

        guard let firstPoint = metrics.dataPoints.first,
              let lastPoint = metrics.dataPoints.last else { return false }

        let dataSpan = lastPoint.timestamp.timeIntervalSince(firstPoint.timestamp)

        // Set lenient minimum spans based on time range
        let minimumSpanSeconds: TimeInterval
        switch selectedTimeRange {
        case .hour:
            minimumSpanSeconds = 30 // 30 seconds minimum
        case .day:
            minimumSpanSeconds = 300 // 5 minutes minimum
        case .week:
            minimumSpanSeconds = 1800 // 30 minutes minimum
        case .month:
            minimumSpanSeconds = 7200 // 2 hours minimum
        }

        return dataSpan >= minimumSpanSeconds
    }

    /// Get a descriptive message about data sufficiency
    var dataSufficiencyMessage: String? {
        guard let metrics = currentMetrics else {
            return "No data available for this time range. Connect your device to start collecting data."
        }

        if metrics.dataPoints.isEmpty {
            return "No data points available for \(selectedTimeRange.rawValue) view"
        }

        if metrics.dataPoints.count == 1 {
            return "Only 1 data point available. Need at least 2 points to show a chart."
        }

        // Check if data spans enough time
        if let firstPoint = metrics.dataPoints.first,
           let lastPoint = metrics.dataPoints.last {
            let dataSpan = lastPoint.timestamp.timeIntervalSince(firstPoint.timestamp)
            let hours = Int(dataSpan / 3600)
            let minutes = Int((dataSpan.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(dataSpan.truncatingRemainder(dividingBy: 60))

            let timeSpanDescription: String
            if hours > 0 {
                timeSpanDescription = "\(hours)h \(minutes)m"
            } else if minutes > 0 {
                timeSpanDescription = "\(minutes)m \(seconds)s"
            } else {
                timeSpanDescription = "\(seconds)s"
            }

            // Check against minimum spans
            let minimumSpanSeconds: TimeInterval
            let minimumSpanText: String
            switch selectedTimeRange {
            case .hour:
                minimumSpanSeconds = 30
                minimumSpanText = "30 seconds"
            case .day:
                minimumSpanSeconds = 300
                minimumSpanText = "5 minutes"
            case .week:
                minimumSpanSeconds = 1800
                minimumSpanText = "30 minutes"
            case .month:
                minimumSpanSeconds = 7200
                minimumSpanText = "2 hours"
            }

            if dataSpan < minimumSpanSeconds {
                return "Data only spans \(timeSpanDescription). Need at least \(minimumSpanText) for \(selectedTimeRange.rawValue) view."
            }
        }

        return nil  // Sufficient data
    }
    
    // MARK: - Private Methods

    private func updateCurrentMetrics() {
        Logger.shared.info("[HistoricalViewModel] 🔄 updateCurrentMetrics() called for selectedTimeRange: \(selectedTimeRange)")

        switch selectedTimeRange {
        case .hour:
            Logger.shared.debug("[HistoricalViewModel] Hour case - hourMetrics state: \(hourMetrics == nil ? "NIL" : "EXISTS with \(hourMetrics!.dataPoints.count) points")")
            currentMetrics = hourMetrics
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
