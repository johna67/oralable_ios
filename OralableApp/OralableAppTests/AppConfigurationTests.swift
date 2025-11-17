//
//  AppConfigurationTests.swift
//  OralableAppTests
//
//  Created: Phase 2 Refactoring - Test Coverage Expansion
//  Unit tests for AppConfiguration constants
//

import XCTest
import CoreBluetooth
@testable import OralableApp

final class AppConfigurationTests: XCTestCase {

    // MARK: - BLE Configuration Tests

    func testBLEServiceUUID() {
        let uuid = AppConfiguration.BLE.tgmServiceUUID

        XCTAssertEqual(uuid.uuidString, "3A0FF000-98C4-46B2-94AF-1AEE0FD4C48E")
    }

    func testBLEMaxReconnectAttempts() {
        XCTAssertEqual(AppConfiguration.BLE.maxReconnectAttempts, 3)
        XCTAssertGreaterThan(AppConfiguration.BLE.maxReconnectAttempts, 0)
    }

    func testBLEReconnectDelaySettings() {
        XCTAssertEqual(AppConfiguration.BLE.reconnectInitialDelay, 1.0)
        XCTAssertEqual(AppConfiguration.BLE.reconnectBackoffMultiplier, 2.0)
        XCTAssertGreaterThan(AppConfiguration.BLE.reconnectInitialDelay, 0)
        XCTAssertGreaterThanOrEqual(AppConfiguration.BLE.reconnectBackoffMultiplier, 1.0)
    }

    func testBLEAutoReconnectEnabled() {
        XCTAssertTrue(AppConfiguration.BLE.autoReconnectEnabled)
    }

    func testBLEScanTimeoutReasonable() {
        let timeout = AppConfiguration.BLE.scanTimeout

        XCTAssertGreaterThan(timeout, 0, "Scan timeout should be positive")
        XCTAssertLessThan(timeout, 120, "Scan timeout should be less than 2 minutes")
    }

    func testBLEMaxConcurrentConnections() {
        let maxConnections = AppConfiguration.BLE.maxConcurrentConnections

        XCTAssertGreaterThan(maxConnections, 0, "Should allow at least one connection")
        XCTAssertLessThanOrEqual(maxConnections, 10, "Should have reasonable upper limit")
    }

    // MARK: - Sensor Configuration Tests

    func testSensorMovementThreshold() {
        let threshold = AppConfiguration.Sensors.movementThreshold

        XCTAssertGreaterThan(threshold, 0)
        XCTAssertLessThan(threshold, 10.0, "Movement threshold should be reasonable")
    }

    func testSensorSignalQualityThreshold() {
        let threshold = AppConfiguration.Sensors.signalQualityThreshold

        XCTAssertGreaterThanOrEqual(threshold, 0)
        XCTAssertLessThanOrEqual(threshold, 100, "Signal quality should be 0-100")
    }

    func testSensorChargingVoltageThreshold() {
        let threshold = AppConfiguration.Sensors.chargingVoltageThreshold

        XCTAssertGreaterThan(threshold, 3.0, "Voltage threshold should be above 3V")
        XCTAssertLessThan(threshold, 5.0, "Voltage threshold should be below 5V")
    }

    func testSensorHistoryBufferSize() {
        let size = AppConfiguration.Sensors.historyBufferSize

        XCTAssertGreaterThan(size, 0)
        XCTAssertLessThan(size, 10000, "Buffer size should be reasonable to avoid memory issues")
    }

    // MARK: - UI Configuration Tests

    func testUISensorDataThrottleInterval() {
        let interval = AppConfiguration.UI.sensorDataThrottleInterval

        XCTAssertGreaterThan(interval, 0, "Throttle interval must be positive")
        XCTAssertLessThan(interval, 1.0, "Throttle interval should be sub-second for responsiveness")
    }

    func testUIMaxWaveformPoints() {
        let maxPoints = AppConfiguration.UI.maxWaveformPoints

        XCTAssertGreaterThan(maxPoints, 0)
        XCTAssertLessThan(maxPoints, 10000, "Max waveform points should be reasonable")
    }

    // MARK: - Data Configuration Tests

    func testDataMaxHistoryDays() {
        let maxDays = AppConfiguration.Data.maxHistoryDays

        XCTAssertGreaterThan(maxDays, 0)
        XCTAssertLessThanOrEqual(maxDays, 365, "Max history days should be <= 1 year")
    }

    func testDataAutoDeleteOldData() {
        // Should be a boolean
        let autoDelete = AppConfiguration.Data.autoDeleteOldData
        XCTAssertNotNil(autoDelete)
    }

    // MARK: - Logging Configuration Tests

    func testLoggingDefaultLevel() {
        let level = AppConfiguration.Logging.defaultLevel

        // LogLevel should be one of the valid cases
        let validLevels: [LogLevel] = [.debug, .info, .warning, .error]
        XCTAssertTrue(validLevels.contains(level), "Default log level should be valid")
    }

    func testLoggingEnableFileLogging() {
        // Should be a boolean
        let enableFileLogging = AppConfiguration.Logging.enableFileLogging
        XCTAssertNotNil(enableFileLogging)
    }

    func testLoggingMaxFileSizeReasonable() {
        let maxSize = AppConfiguration.Logging.maxFileSize

        XCTAssertGreaterThan(maxSize, 1024, "Max file size should be at least 1KB")
        XCTAssertLessThan(maxSize, 100_000_000, "Max file size should be reasonable (< 100MB)")
    }

    // MARK: - Feature Flags Tests

    func testFeatureEnableHealthKitIntegration() {
        // Should be a boolean
        let enabled = AppConfiguration.Features.enableHealthKitIntegration
        XCTAssertNotNil(enabled)
    }

    func testFeatureEnableCloudSync() {
        // Should be a boolean
        let enabled = AppConfiguration.Features.enableCloudSync
        XCTAssertNotNil(enabled)
    }

    func testFeatureEnableAdvancedAnalytics() {
        // Should be a boolean
        let enabled = AppConfiguration.Features.enableAdvancedAnalytics
        XCTAssertNotNil(enabled)
    }

    // MARK: - Debug Configuration Tests

    func testDebugEnableMockData() {
        // Should be a boolean
        let enabled = AppConfiguration.Debug.enableMockData
        XCTAssertNotNil(enabled)
    }

    func testDebugEnableVerboseLogging() {
        // Should be a boolean
        let enabled = AppConfiguration.Debug.enableVerboseLogging
        XCTAssertNotNil(enabled)
    }

    // MARK: - Integration Tests

    func testThrottleIntervalWorksWithBufferSize() {
        let throttleInterval = AppConfiguration.UI.sensorDataThrottleInterval
        let bufferSize = AppConfiguration.Sensors.historyBufferSize

        // At 10Hz (0.1s interval), buffer should last at least 1 minute
        let estimatedSeconds = Double(bufferSize) * throttleInterval
        XCTAssertGreaterThanOrEqual(estimatedSeconds, 60, "Buffer should hold at least 1 minute of data")
    }

    func testReconnectBackoffProgression() {
        let initialDelay = AppConfiguration.BLE.reconnectInitialDelay
        let multiplier = AppConfiguration.BLE.reconnectBackoffMultiplier
        let maxAttempts = AppConfiguration.BLE.maxReconnectAttempts

        var totalDelay: TimeInterval = 0
        for attempt in 0..<maxAttempts {
            let delay = initialDelay * pow(multiplier, Double(attempt))
            totalDelay += delay
        }

        // Total backoff shouldn't be excessive (< 5 minutes)
        XCTAssertLessThan(totalDelay, 300, "Total reconnect time should be reasonable")
    }
}
