import Foundation
import Foundation
import Combine
import UIKit

/// Manager for caching and updating historical metrics
/// This prevents recalculating aggregations on every view update
class HistoricalDataManager: ObservableObject {
    // MARK: - Published Properties
    @Published var hourMetrics: HistoricalMetrics?
    @Published var dayMetrics: HistoricalMetrics?
    @Published var weekMetrics: HistoricalMetrics?
    @Published var monthMetrics: HistoricalMetrics?

    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?

    // MARK: - Private Properties
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60.0 // Update every 60 seconds

    // Reference to the BLE manager (internal for access by ViewModel)
    internal weak var bleManager: OralableBLE?

    // Throttling to prevent excessive updates
    private var lastMetricsUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 2.0 // Minimum 2 seconds between updates
    private var pendingUpdateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(bleManager: OralableBLE?) {
        self.bleManager = bleManager
        // DISABLED: Historical view should show static snapshots, not auto-update
        // Auto-updates would make the view refresh constantly, which is not desired
        // Updates only happen when:
        // - User opens the view (manual call from ViewModel)
        // - User changes time range
        // - User pulls to refresh (if implemented)
    }
    
    deinit {
        stopAutoUpdate()
    }
    
    // MARK: - Public Methods
    
    /// Manually trigger an update of all metrics (with throttling)
    @MainActor func updateAllMetrics() {
        // THROTTLING: Check if we've updated too recently
        if let lastUpdate = lastMetricsUpdateTime {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate < minimumUpdateInterval {
                Logger.shared.debug("[HistoricalDataManager] ⏸️ Throttling update (last update \(String(format: "%.1f", timeSinceLastUpdate))s ago, min interval: \(minimumUpdateInterval)s)")

                // Cancel any pending update and schedule a new one
                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(self?.minimumUpdateInterval ?? 2.0) * 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.performMetricsUpdate()
                }
                return
            }
        }

        // Proceed with immediate update
        performMetricsUpdate()
    }

    /// Internal method that performs the actual metrics update
    @MainActor private func performMetricsUpdate() {
        guard let ble = bleManager else {
            Logger.shared.warning("[HistoricalDataManager] ⚠️ BLE manager is nil, cannot update metrics")
            clearAllMetrics()
            return
        }

        if ble.sensorDataHistory.isEmpty {
            Logger.shared.warning("[HistoricalDataManager] ⚠️ No sensor data available (sensorDataHistory is empty), clearing metrics")
            clearAllMetrics()
            return
        }

        Logger.shared.info("[HistoricalDataManager] ✅ Starting metrics update | Sensor data count: \(ble.sensorDataHistory.count)")
        isUpdating = true
        lastMetricsUpdateTime = Date()

        // Use Task for proper async handling with main actor isolation
        // Move heavy computation to background thread
        Task.detached { [weak self, bleManager] in
            guard let self = self, let ble = bleManager else { return }

            // Perform expensive aggregation off the main thread
            let sensorData = await ble.sensorDataHistory  // Access published property

            let hourRange = TimeRange.hour
            let dayRange = TimeRange.day
            let weekRange = TimeRange.week
            let monthRange = TimeRange.month

            // These aggregation calls are now off the main thread
            let hour = await ble.getHistoricalMetrics(for: hourRange)
            let day = await ble.getHistoricalMetrics(for: dayRange)
            let week = await ble.getHistoricalMetrics(for: weekRange)
            let month = await ble.getHistoricalMetrics(for: monthRange)

            // Update published properties on main actor
            await MainActor.run { [weak self] in
                self?.hourMetrics = hour
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

        // Use Task for proper async handling with main actor isolation
        Task { @MainActor [weak self] in
            // Access main-actor isolated BLE methods on main actor
            let metrics = ble.getHistoricalMetrics(for: range)

            if let metrics = metrics {
                let avgHR = metrics.dataPoints.compactMap { $0.averageHeartRate }.reduce(0, +) / Double(max(metrics.dataPoints.count, 1))
                let avgSpO2 = metrics.dataPoints.compactMap { $0.averageSpO2 }.reduce(0, +) / Double(max(metrics.dataPoints.count, 1))
                Logger.shared.info("[HistoricalDataManager] ✅ Metrics calculated for \(range) | HR avg: \(String(format: "%.0f", avgHR)) bpm | SpO2 avg: \(String(format: "%.1f", avgSpO2))% | Total samples: \(metrics.totalSamples) | Data points: \(metrics.dataPoints.count)")
            } else {
                Logger.shared.warning("[HistoricalDataManager] ⚠️ No metrics calculated for \(range)")
            }

            // Update published properties on main actor
            switch range {
            case TimeRange.hour:
                self?.hourMetrics = metrics
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
    
    /// Get metrics for a specific time range
    /// - Parameter range: The time range
    /// - Returns: Cached metrics or nil if not available
    func getMetrics(for range: TimeRange) -> HistoricalMetrics? {
        switch range {
        case TimeRange.hour: return hourMetrics
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
        hourMetrics = nil
        dayMetrics = nil
        weekMetrics = nil
        monthMetrics = nil
        lastUpdateTime = nil
    }

    /// Clear metrics for a specific range
    /// - Parameter range: The time range to clear
    func clearMetrics(for range: TimeRange) {
        switch range {
        case TimeRange.hour: hourMetrics = nil
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

    // DISABLED: Auto-update functionality removed for static historical snapshots
    // Historical view should NOT auto-refresh, only Dashboard should have real-time data
    /*
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
    */
}

// MARK: - Convenience Computed Properties
extension HistoricalDataManager {
    
    /// Returns true if any metrics are available
    var hasAnyMetrics: Bool {
        return hourMetrics != nil || dayMetrics != nil || weekMetrics != nil || monthMetrics != nil
    }

    /// Returns a summary string of available metrics
    var availabilityDescription: String {
        var available: [String] = []

        if hourMetrics != nil { available.append("Hour") }
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
