import Foundation
import Foundation
import Combine
import UIKit

/// Manager for caching and updating historical metrics
/// This prevents recalculating aggregations on every view update
class HistoricalDataManager: ObservableObject {
    static let shared = HistoricalDataManager(bleManager: OralableBLE.shared)// ADD THIS LINE

    
    // MARK: - Published Properties
    @Published var dayMetrics: HistoricalMetrics?
    @Published var weekMetrics: HistoricalMetrics?
    @Published var monthMetrics: HistoricalMetrics?
    
    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    
    // MARK: - Private Properties
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60.0 // Update every 60 seconds
    
    // Reference to the BLE manager
    private weak var bleManager: OralableBLE?
    
    // MARK: - Initialization
    init(bleManager: OralableBLE) {
        self.bleManager = bleManager
        setupAutoUpdate()
    }
    
    deinit {
        stopAutoUpdate()
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger an update of all metrics
    @MainActor func updateAllMetrics() {
        guard let ble = bleManager, !ble.sensorDataHistory.isEmpty else {
            Logger.shared.debug("[HistoricalDataManager] No sensor data available, clearing metrics")
            clearAllMetrics()
            return
        }

        Logger.shared.info("[HistoricalDataManager] Starting metrics update | Sensor data count: \(ble.sensorDataHistory.count)")
        isUpdating = true

        // Use background queue for calculations to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let dayRange = TimeRange.day
            let weekRange = TimeRange.week
            let monthRange = TimeRange.month

            Logger.shared.debug("[HistoricalDataManager] Calculating metrics for Day, Week, Month ranges...")

            let day = ble.getHistoricalMetrics(for: dayRange)
            let week = ble.getHistoricalMetrics(for: weekRange)
            let month = ble.getHistoricalMetrics(for: monthRange)

            Logger.shared.info("[HistoricalDataManager] Metrics calculated | Day: \(day != nil ? "✓" : "✗") | Week: \(week != nil ? "✓" : "✗") | Month: \(month != nil ? "✓" : "✗")")

            if let day = day {
                Logger.shared.debug("[HistoricalDataManager] Day metrics | HR avg: \(String(format: "%.0f", day.averageHeartRate)) bpm | SpO2 avg: \(String(format: "%.1f", day.averageSpO2))% | Samples: \(day.sampleCount)")
            }

            DispatchQueue.main.async {
                self?.dayMetrics = day
                self?.weekMetrics = week
                self?.monthMetrics = month
                self?.lastUpdateTime = Date()
                self?.isUpdating = false
                Logger.shared.info("[HistoricalDataManager] ✅ Metrics update completed and published to UI")
            }
        }
    }
    
    /// Update metrics for a specific time range only
    /// - Parameter range: The time range to update
    @MainActor func updateMetrics(for range: TimeRange) {
        guard let ble = bleManager, !ble.sensorDataHistory.isEmpty else {
            Logger.shared.debug("[HistoricalDataManager] No sensor data available for range: \(range), clearing metrics")
            clearMetrics(for: range)
            return
        }

        Logger.shared.debug("[HistoricalDataManager] Updating metrics for range: \(range) | Data count: \(ble.sensorDataHistory.count)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let metrics = ble.getHistoricalMetrics(for: range)

            if let metrics = metrics {
                Logger.shared.info("[HistoricalDataManager] ✅ Metrics calculated for \(range) | HR avg: \(String(format: "%.0f", metrics.averageHeartRate)) bpm | SpO2 avg: \(String(format: "%.1f", metrics.averageSpO2))% | Samples: \(metrics.sampleCount)")
            } else {
                Logger.shared.warning("[HistoricalDataManager] ⚠️ No metrics calculated for \(range)")
            }

            DispatchQueue.main.async {
                switch range {
                case TimeRange.hour:
                    // Hour metrics are no longer supported
                    break
                case TimeRange.day:
                    self?.dayMetrics = metrics
                case TimeRange.week:
                    self?.weekMetrics = metrics
                case TimeRange.month:
                    self?.monthMetrics = metrics
                }
                self?.lastUpdateTime = Date()
                Logger.shared.debug("[HistoricalDataManager] Metrics for \(range) published to UI")
            }
        }
    }
    
    /// Get metrics for a specific time range
    /// - Parameter range: The time range
    /// - Returns: Cached metrics or nil if not available
    func getMetrics(for range: TimeRange) -> HistoricalMetrics? {
        switch range {
        case TimeRange.hour: return nil // Hour metrics are no longer supported
        case TimeRange.day: return dayMetrics
        case TimeRange.week: return weekMetrics
        case TimeRange.month: return monthMetrics
        }
    }
    
    /// Check if metrics are available for a range
    /// - Parameter range: The time range to check
    /// - Returns: True if metrics exist
    func hasMetrics(for range: TimeRange) -> Bool {
        return getMetrics(for: range) != nil
    }
    
    /// Clear all cached metrics
    func clearAllMetrics() {
        dayMetrics = nil
        weekMetrics = nil
        monthMetrics = nil
        lastUpdateTime = nil
    }
    
    /// Clear metrics for a specific range
    /// - Parameter range: The time range to clear
    func clearMetrics(for range: TimeRange) {
        switch range {
        case TimeRange.hour: break // Hour metrics are no longer supported
        case TimeRange.day: dayMetrics = nil
        case TimeRange.week: weekMetrics = nil
        case TimeRange.month: monthMetrics = nil
        }
    }
    
    // MARK: - Auto-Update Management
    
    /// Start automatic periodic updates
    @MainActor func startAutoUpdate() {
        stopAutoUpdate()
        
        // Initial update
        updateAllMetrics()
        
        // Schedule periodic updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateAllMetrics()
        }
    }
    
    /// Stop automatic updates
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Set custom update interval
    /// - Parameter interval: Update interval in seconds
    func setUpdateInterval(_ interval: TimeInterval) {
        guard interval >= 10 else { return } // Minimum 10 seconds
        
        let wasRunning = updateTimer != nil
        stopAutoUpdate()
        
        if wasRunning {
            updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.updateAllMetrics()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAutoUpdate() {
        // Observe when the app becomes active to refresh data
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAllMetrics()
        }
    }
}

// MARK: - Convenience Computed Properties
extension HistoricalDataManager {
    
    /// Returns true if any metrics are available
    var hasAnyMetrics: Bool {
        return dayMetrics != nil || weekMetrics != nil || monthMetrics != nil
    }
    
    /// Returns a summary string of available metrics
    var availabilityDescription: String {
        var available: [String] = []
        
        if dayMetrics != nil { available.append("Day") }
        if weekMetrics != nil { available.append("Week") }
        if monthMetrics != nil { available.append("Month") }
        
        return available.isEmpty ? "No metrics available" : "Available: \(available.joined(separator: ", "))"
    }
    
    /// Time since last update in seconds
    var timeSinceLastUpdate: TimeInterval? {
        guard let lastUpdate = lastUpdateTime else { return nil }
        return Date().timeIntervalSince(lastUpdate)
    }
}
