import Foundation
import Combine
import UIKit

/// Manager for caching and updating historical metrics
/// This prevents recalculating aggregations on every view update
class HistoricalDataManager: ObservableObject {
    
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
    func updateAllMetrics() {
        guard let ble = bleManager, !ble.historicalData.isEmpty else {
            clearAllMetrics()
            return
        }
        
        isUpdating = true
        
        // Use background queue for calculations to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let day = ble.getHistoricalMetrics(for: .day)
            let week = ble.getHistoricalMetrics(for: .week)
            let month = ble.getHistoricalMetrics(for: .month)
            
            DispatchQueue.main.async {
                self?.dayMetrics = day
                self?.weekMetrics = week
                self?.monthMetrics = month
                self?.lastUpdateTime = Date()
                self?.isUpdating = false
            }
        }
    }
    
    /// Update metrics for a specific time range only
    /// - Parameter range: The time range to update
    func updateMetrics(for range: TimeRange) {
        guard let ble = bleManager, !ble.historicalData.isEmpty else {
            clearMetrics(for: range)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let metrics = ble.getHistoricalMetrics(for: range)
            
            DispatchQueue.main.async {
                switch range {
                case .hour:
                    // Hour metrics are no longer supported
                    break
                case .day:
                    self?.dayMetrics = metrics
                case .week:
                    self?.weekMetrics = metrics
                case .month:
                    self?.monthMetrics = metrics
                }
                self?.lastUpdateTime = Date()
            }
        }
    }
    
    /// Get metrics for a specific time range
    /// - Parameter range: The time range
    /// - Returns: Cached metrics or nil if not available
    func getMetrics(for range: TimeRange) -> HistoricalMetrics? {
        switch range {
        case .hour: return nil // Hour metrics are no longer supported
        case .day: return dayMetrics
        case .week: return weekMetrics
        case .month: return monthMetrics
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
        case .hour: break // Hour metrics are no longer supported
        case .day: dayMetrics = nil
        case .week: weekMetrics = nil
        case .month: monthMetrics = nil
        }
    }
    
    // MARK: - Auto-Update Management
    
    /// Start automatic periodic updates
    func startAutoUpdate() {
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
