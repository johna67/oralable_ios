//
//  DataThrottlerTests.swift
//  OralableAppTests
//
//  Created: Phase 2 Refactoring
//  Tests for DataThrottler actor
//

import XCTest
@testable import OralableApp

final class DataThrottlerTests: XCTestCase {

    // MARK: - Basic Throttling Tests

    func testThrottlesFrequentUpdates() async {
        // Given: A throttler with 100ms interval
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Sending multiple values rapidly
        let first = await throttler.throttle(1)
        let second = await throttler.throttle(2)
        let third = await throttler.throttle(3)

        // Then: Only first value should pass through
        XCTAssertNotNil(first, "First value should always pass through")
        XCTAssertEqual(first, 1)
        XCTAssertNil(second, "Second value should be throttled")
        XCTAssertNil(third, "Third value should be throttled")
    }

    func testEmitsAfterInterval() async throws {
        // Given: A throttler with 100ms interval
        let throttler = DataThrottler<String>(minimumInterval: 0.1)

        // When: Sending first value
        let first = await throttler.throttle("first")
        XCTAssertEqual(first, "first")

        // Then: Wait for interval to pass
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // When: Sending second value after interval
        let second = await throttler.throttle("second")

        // Then: Second value should pass through
        XCTAssertNotNil(second, "Value after interval should pass through")
        XCTAssertEqual(second, "second")
    }

    func testStoresLatestValue() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Sending multiple values
        _ = await throttler.throttle(1)
        _ = await throttler.throttle(2)
        _ = await throttler.throttle(3)

        // Then: Latest value should be stored
        let latest = await throttler.latestValue()
        XCTAssertEqual(latest, 3, "Latest value should be 3")
    }

    // MARK: - Flush Tests

    func testFlushEmitsPendingValue() async {
        // Given: A throttler with pending values
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)
        _ = await throttler.throttle(1) // Emitted
        _ = await throttler.throttle(2) // Pending
        _ = await throttler.throttle(3) // Pending (overwrites 2)

        // When: Flushing
        let flushed = await throttler.flush()

        // Then: Pending value should be returned
        XCTAssertEqual(flushed, 3)
    }

    func testFlushClearsPendingValue() async {
        // Given: A throttler with pending value
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)
        _ = await throttler.throttle(1)
        _ = await throttler.throttle(2)

        // When: Flushing
        _ = await throttler.flush()

        // Then: Pending value should be cleared
        let latest = await throttler.latestValue()
        XCTAssertNil(latest, "Pending value should be cleared after flush")
    }

    // MARK: - Statistics Tests

    func testStatisticsTracksReceivedCount() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Sending 5 values
        for i in 1...5 {
            _ = await throttler.throttle(i)
        }

        // Then: Received count should be 5
        let stats = await throttler.statistics()
        XCTAssertEqual(stats.received, 5)
    }

    func testStatisticsTracksEmittedCount() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Sending 5 values rapidly (only first should emit)
        for i in 1...5 {
            _ = await throttler.throttle(i)
        }

        // Then: Emitted count should be 1
        let stats = await throttler.statistics()
        XCTAssertEqual(stats.emitted, 1)
    }

    func testStatisticsCalculatesDropRate() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Sending 10 values rapidly
        for i in 1...10 {
            _ = await throttler.throttle(i)
        }

        // Then: Drop rate should be 90% (9 out of 10 dropped)
        let stats = await throttler.statistics()
        XCTAssertEqual(stats.dropRate, 90.0, accuracy: 0.1)
    }

    // MARK: - Reset Tests

    func testResetClearsState() async {
        // Given: A throttler with data
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)
        _ = await throttler.throttle(1)
        _ = await throttler.throttle(2)

        // When: Resetting
        await throttler.reset()

        // Then: State should be cleared
        let stats = await throttler.statistics()
        XCTAssertEqual(stats.received, 0)
        XCTAssertEqual(stats.emitted, 0)

        let latest = await throttler.latestValue()
        XCTAssertNil(latest)
    }

    func testResetAllowsImmediateEmission() async {
        // Given: A throttler that recently emitted
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)
        _ = await throttler.throttle(1) // Emitted

        // When: Resetting and sending new value
        await throttler.reset()
        let value = await throttler.throttle(2)

        // Then: New value should emit immediately
        XCTAssertNotNil(value)
        XCTAssertEqual(value, 2)
    }

    // MARK: - Edge Cases

    func testZeroInterval() async {
        // Given: A throttler with zero interval
        let throttler = DataThrottler<Int>(minimumInterval: 0)

        // When: Sending multiple values
        let first = await throttler.throttle(1)
        let second = await throttler.throttle(2)
        let third = await throttler.throttle(3)

        // Then: All values should pass through (no throttling)
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotNil(third)
    }

    func testShouldEmitCheck() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Before any emissions
        let shouldEmitBefore = await throttler.shouldEmit()
        // Then: Should be true
        XCTAssertTrue(shouldEmitBefore)

        // When: After one emission
        _ = await throttler.throttle(1)
        let shouldEmitAfter = await throttler.shouldEmit()
        // Then: Should be false (too soon)
        XCTAssertFalse(shouldEmitAfter)
    }

    func testIntervalProperty() async {
        // Given: A throttler with specific interval
        let interval: TimeInterval = 0.25
        let throttler = DataThrottler<Int>(minimumInterval: interval)

        // When: Checking interval
        let retrievedInterval = await throttler.interval

        // Then: Should match initialization value
        XCTAssertEqual(retrievedInterval, interval)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentAccess() async {
        // Given: A throttler
        let throttler = DataThrottler<Int>(minimumInterval: 0.1)

        // When: Multiple concurrent tasks sending values
        await withTaskGroup(of: Void.self) { group in
            for i in 1...100 {
                group.addTask {
                    _ = await throttler.throttle(i)
                }
            }
        }

        // Then: Should handle concurrent access safely (actor ensures thread safety)
        let stats = await throttler.statistics()
        XCTAssertEqual(stats.received, 100)
        XCTAssertGreaterThan(stats.received, stats.emitted)
    }

    // MARK: - Performance Tests

    func testPerformance() {
        measure {
            Task {
                let throttler = DataThrottler<Int>(minimumInterval: 0.01)
                for i in 1...1000 {
                    _ = await throttler.throttle(i)
                }
            }
        }
    }
}
