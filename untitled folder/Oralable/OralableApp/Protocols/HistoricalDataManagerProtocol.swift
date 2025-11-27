//
//  HistoricalDataManagerProtocol.swift
//  OralableApp
//
//  Created: Refactoring Phase 1
//  Purpose: Protocol abstraction for HistoricalDataManager to enable dependency injection and testing
//

import Foundation
import Combine

/// Protocol defining the historical data manager interface
/// Enables dependency injection, mocking, and testing
@MainActor
protocol HistoricalDataManagerProtocol: AnyObject {
    // MARK: - Metrics State
    var minuteMetrics: HistoricalMetrics? { get }
    var hourMetrics: HistoricalMetrics? { get }
    var dayMetrics: HistoricalMetrics? { get }
    var weekMetrics: HistoricalMetrics? { get }
    var monthMetrics: HistoricalMetrics? { get }

    // MARK: - Update State
    var isUpdating: Bool { get }
    var lastUpdateTime: Date? { get }

    // MARK: - Actions
    func updateAllMetrics()
    func updateMetrics(for range: TimeRange)
    func getMetrics(for range: TimeRange) -> HistoricalMetrics?
    func hasMetrics(for range: TimeRange) -> Bool
    func clearAllMetrics()
    func clearMetrics(for range: TimeRange)

    // MARK: - Auto-Update Management
    func startAutoUpdate()
    func stopAutoUpdate()
    func setUpdateInterval(_ interval: TimeInterval)

    // MARK: - Computed Properties
    var hasAnyMetrics: Bool { get }
    var availabilityDescription: String { get }
    var timeSinceLastUpdate: TimeInterval? { get }

    // MARK: - Publishers for Reactive UI
    var minuteMetricsPublisher: Published<HistoricalMetrics?>.Publisher { get }
    var hourMetricsPublisher: Published<HistoricalMetrics?>.Publisher { get }
    var dayMetricsPublisher: Published<HistoricalMetrics?>.Publisher { get }
    var weekMetricsPublisher: Published<HistoricalMetrics?>.Publisher { get }
    var monthMetricsPublisher: Published<HistoricalMetrics?>.Publisher { get }
    var isUpdatingPublisher: Published<Bool>.Publisher { get }
    var lastUpdateTimePublisher: Published<Date?>.Publisher { get }
}

// MARK: - HistoricalDataManager Conformance

extension HistoricalDataManager: HistoricalDataManagerProtocol {
    var minuteMetricsPublisher: Published<HistoricalMetrics?>.Publisher { $minuteMetrics }
    var hourMetricsPublisher: Published<HistoricalMetrics?>.Publisher { $hourMetrics }
    var dayMetricsPublisher: Published<HistoricalMetrics?>.Publisher { $dayMetrics }
    var weekMetricsPublisher: Published<HistoricalMetrics?>.Publisher { $weekMetrics }
    var monthMetricsPublisher: Published<HistoricalMetrics?>.Publisher { $monthMetrics }
    var isUpdatingPublisher: Published<Bool>.Publisher { $isUpdating }
    var lastUpdateTimePublisher: Published<Date?>.Publisher { $lastUpdateTime }
}
