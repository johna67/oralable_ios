//
//  DataThrottler.swift
//  OralableApp
//
//  Created: Phase 2 Refactoring
//  Thread-safe data throttling using Swift actors
//

import Foundation

/// Actor-based data throttler to prevent UI freezes from high-frequency data streams
///
/// Usage:
/// ```swift
/// let throttler = DataThrottler<SensorReading>(minimumInterval: 0.1)
///
/// for reading in dataStream {
///     if let throttled = await throttler.throttle(reading) {
///         // This will only emit every 0.1 seconds
///         updateUI(with: throttled)
///     }
/// }
/// ```
actor DataThrottler<T> {

    // MARK: - Properties

    /// Last time a value was emitted
    private var lastEmissionTime: Date?

    /// Minimum time interval between emissions
    private let minimumInterval: TimeInterval

    /// Most recent value received (even if not emitted)
    private var pendingValue: T?

    /// Total number of values received
    private var receivedCount: Int = 0

    /// Total number of values emitted (after throttling)
    private var emittedCount: Int = 0

    // MARK: - Initialization

    /// Create a new data throttler
    /// - Parameter minimumInterval: Minimum time between emissions in seconds
    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    // MARK: - Throttling

    /// Throttle a value based on time interval
    /// - Parameter value: The value to potentially throttle
    /// - Returns: The value if enough time has passed, nil otherwise
    func throttle(_ value: T) -> T? {
        let now = Date()
        receivedCount += 1

        // Always store the latest value
        pendingValue = value

        // Check if enough time has passed since last emission
        if let last = lastEmissionTime {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < minimumInterval {
                // Too soon - drop this value
                return nil
            }
        }

        // Enough time has passed - emit this value
        lastEmissionTime = now
        emittedCount += 1
        let valueToEmit = pendingValue
        pendingValue = nil
        return valueToEmit
    }

    /// Force emit the latest pending value, regardless of time interval
    /// Useful when you need the most recent value (e.g., when stopping a stream)
    /// - Returns: The latest pending value, if any
    func flush() -> T? {
        defer {
            pendingValue = nil
            if pendingValue != nil {
                lastEmissionTime = Date()
                emittedCount += 1
            }
        }
        return pendingValue
    }

    /// Get the latest value without affecting throttling state
    /// - Returns: The most recent value received, even if not emitted
    func latestValue() -> T? {
        pendingValue
    }

    /// Reset the throttler state
    func reset() {
        lastEmissionTime = nil
        pendingValue = nil
        receivedCount = 0
        emittedCount = 0
    }

    // MARK: - Statistics

    /// Get throttling statistics
    /// - Returns: Tuple of (received count, emitted count, drop rate percentage)
    func statistics() -> (received: Int, emitted: Int, dropRate: Double) {
        let dropRate = receivedCount > 0 ? Double(receivedCount - emittedCount) / Double(receivedCount) * 100.0 : 0.0
        return (receivedCount, emittedCount, dropRate)
    }

    /// Get the configured minimum interval
    var interval: TimeInterval {
        minimumInterval
    }
}

// MARK: - Convenience Extensions

extension DataThrottler {
    /// Check if a value should be emitted based on current state
    /// Does not modify state - useful for testing
    /// - Returns: True if enough time has passed for emission
    func shouldEmit() -> Bool {
        guard let last = lastEmissionTime else {
            return true // First emission
        }
        let elapsed = Date().timeIntervalSince(last)
        return elapsed >= minimumInterval
    }
}

// MARK: - Sendable Conformance

// DataThrottler is automatically Sendable as an actor
// T does not need to be Sendable as it's isolated within the actor
