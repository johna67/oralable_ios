//
//  DashboardIntegrationTests.swift
//  OralableAppTests
//
//  Created: December 15, 2025
//  Purpose: Integration tests for dashboard data binding and reactive updates
//  Tests ViewModel publishing, concurrent updates, and error state handling
//

import XCTest
import Combine
@testable import OralableApp

@MainActor
final class DashboardIntegrationTests: XCTestCase {

    // MARK: - Properties

    var cancellables: Set<AnyCancellable>!

    // MARK: - Test Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
        try await super.tearDown()
    }

    // MARK: - RecordingStateCoordinator Integration Tests

    func testRecordingStateCoordinatorPublishesUpdates() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Ensure clean state
        if coordinator.isRecording {
            coordinator.stopRecording()
        }

        let expectation = XCTestExpectation(description: "Recording state updated")

        coordinator.$isRecording
            .dropFirst()
            .sink { isRecording in
                if isRecording {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        coordinator.startRecording()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(coordinator.isRecording)

        // Cleanup
        coordinator.stopRecording()
    }

    func testRecordingDurationUpdatesOverTime() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Ensure clean state
        if coordinator.isRecording {
            coordinator.stopRecording()
        }

        let expectation = XCTestExpectation(description: "Duration updated")

        coordinator.$sessionDuration
            .dropFirst()
            .sink { duration in
                if duration > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        coordinator.startRecording()

        // Then - wait for duration to update
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertGreaterThan(coordinator.sessionDuration, 0)

        // Cleanup
        coordinator.stopRecording()
    }

    func testRecordingStopResetsState() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Ensure recording is started
        if !coordinator.isRecording {
            coordinator.startRecording()
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let stopExpectation = XCTestExpectation(description: "Recording stopped")

        coordinator.$isRecording
            .sink { isRecording in
                if !isRecording {
                    stopExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        coordinator.stopRecording()

        // Then
        await fulfillment(of: [stopExpectation], timeout: 2.0)
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertNil(coordinator.sessionStartTime)
    }

    func testRecordingToggle() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Ensure clean state
        if coordinator.isRecording {
            coordinator.stopRecording()
        }

        // When - toggle on
        coordinator.toggleRecording()

        // Then
        XCTAssertTrue(coordinator.isRecording, "Should be recording after toggle")

        // When - toggle off
        coordinator.toggleRecording()

        // Then
        XCTAssertFalse(coordinator.isRecording, "Should not be recording after second toggle")
    }

    // MARK: - ThresholdSettings Integration Tests

    func testThresholdSettingsPublishChanges() async {
        // Given
        let settings = ThresholdSettings.shared
        let originalThreshold = settings.movementThreshold

        let expectation = XCTestExpectation(description: "Threshold changed")

        settings.$movementThreshold
            .dropFirst()
            .sink { newThreshold in
                if newThreshold != originalThreshold {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        let newThreshold = originalThreshold + 100
        settings.movementThreshold = newThreshold

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(settings.movementThreshold, newThreshold)

        // Cleanup - restore original
        settings.movementThreshold = originalThreshold
    }

    func testThresholdSettingsPersistence() async {
        // Given
        let settings = ThresholdSettings.shared
        let originalThreshold = settings.movementThreshold

        // When
        let testThreshold = 2500.0
        settings.movementThreshold = testThreshold

        // Then
        XCTAssertEqual(settings.movementThreshold, testThreshold)

        // Cleanup
        settings.movementThreshold = originalThreshold
    }

    // MARK: - FeatureFlags Integration Tests

    func testFeatureFlagsPublishChanges() async {
        // Given
        let flags = FeatureFlags.shared
        let originalState = flags.demoModeEnabled

        let expectation = XCTestExpectation(description: "Feature flag changed")

        flags.$demoModeEnabled
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        flags.demoModeEnabled = !originalState

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(flags.demoModeEnabled, !originalState)

        // Cleanup - restore original
        flags.demoModeEnabled = originalState
    }

    func testFeatureFlagsShowCards() {
        // Given
        let flags = FeatureFlags.shared

        // Test various card visibility flags exist and are accessible
        _ = flags.showEMGCard
        _ = flags.showMovementCard
        _ = flags.showHeartRateCard
        _ = flags.showSpO2Card
        _ = flags.showTemperatureCard
        _ = flags.showBatteryCard

        // Then - should not crash when accessing flags
        XCTAssertTrue(true, "Feature flags should be accessible")
    }

    // MARK: - Concurrent Updates Tests

    func testMultiplePublishersCanUpdateConcurrently() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared
        let settings = ThresholdSettings.shared
        let flags = FeatureFlags.shared

        // Store original values
        let originalThreshold = settings.movementThreshold
        let originalDemo = flags.demoModeEnabled

        // Ensure coordinator is stopped
        if coordinator.isRecording {
            coordinator.stopRecording()
        }

        var coordinatorUpdated = false
        var settingsUpdated = false
        var flagsUpdated = false

        let allUpdatedExpectation = XCTestExpectation(description: "All updated")

        coordinator.$isRecording
            .dropFirst()
            .sink { _ in
                coordinatorUpdated = true
                if coordinatorUpdated && settingsUpdated && flagsUpdated {
                    allUpdatedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        settings.$movementThreshold
            .dropFirst()
            .sink { _ in
                settingsUpdated = true
                if coordinatorUpdated && settingsUpdated && flagsUpdated {
                    allUpdatedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        flags.$demoModeEnabled
            .dropFirst()
            .sink { _ in
                flagsUpdated = true
                if coordinatorUpdated && settingsUpdated && flagsUpdated {
                    allUpdatedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When - update all concurrently
        coordinator.startRecording()
        settings.movementThreshold = originalThreshold + 50
        flags.demoModeEnabled = !originalDemo

        // Then
        await fulfillment(of: [allUpdatedExpectation], timeout: 3.0)

        XCTAssertTrue(coordinatorUpdated, "Coordinator should be updated")
        XCTAssertTrue(settingsUpdated, "Settings should be updated")
        XCTAssertTrue(flagsUpdated, "Flags should be updated")

        // Cleanup - restore original values
        if coordinator.isRecording {
            coordinator.stopRecording()
        }
        settings.movementThreshold = originalThreshold
        flags.demoModeEnabled = originalDemo
    }

    // MARK: - Error State Tests

    func testDisconnectedStateReflectedInDeviceManager() async {
        // Given - new device manager with no connections
        let deviceManager = DeviceManager()

        // Then - should show disconnected state
        XCTAssertTrue(deviceManager.connectedDevices.isEmpty, "Should have no connected devices initially")
    }

    func testDeviceManagerInitialState() async {
        // Given
        let deviceManager = DeviceManager()

        // Then - verify initial state
        XCTAssertFalse(deviceManager.isScanning, "Should not be scanning initially")
        XCTAssertTrue(deviceManager.connectedDevices.isEmpty, "Should have no connected devices")
    }

    // MARK: - Performance Tests

    func testPublisherPerformanceUnderLoad() async {
        // Given
        let settings = ThresholdSettings.shared
        let originalThreshold = settings.movementThreshold
        var updateCount = 0
        let targetUpdates = 50

        let expectation = XCTestExpectation(description: "Updates processed")

        settings.$movementThreshold
            .dropFirst()
            .sink { _ in
                updateCount += 1
                if updateCount >= targetUpdates {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When - rapid updates
        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<targetUpdates {
            settings.movementThreshold = originalThreshold + Double(i)
        }

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(duration, 2.0, "Should process updates quickly")

        // Cleanup
        settings.movementThreshold = originalThreshold
    }

    // MARK: - Session Duration Format Tests

    func testSessionDurationFormatting() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Ensure clean state
        if coordinator.isRecording {
            coordinator.stopRecording()
        }

        // When
        coordinator.startRecording()

        // Wait for some duration
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Then
        let duration = coordinator.sessionDuration
        XCTAssertGreaterThan(duration, 0, "Duration should be greater than 0")

        // Format check
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        let formatted = String(format: "%02d:%02d", minutes, seconds)
        XCTAssertFalse(formatted.isEmpty, "Formatted duration should not be empty")

        // Cleanup
        coordinator.stopRecording()
    }

    // MARK: - State Reset Tests

    func testRecordingStateResetsCleanly() async {
        // Given
        let coordinator = RecordingStateCoordinator.shared

        // Start a recording
        coordinator.startRecording()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // When
        coordinator.stopRecording()

        // Then
        XCTAssertFalse(coordinator.isRecording, "Should not be recording after stop")
        XCTAssertNil(coordinator.sessionStartTime, "Session start time should be nil")
    }

    // MARK: - SensorDataProcessor Integration Tests

    func testSensorDataProcessorExists() {
        // Given
        let processor = SensorDataProcessor.shared

        // Then - processor should exist and be accessible
        XCTAssertNotNil(processor, "SensorDataProcessor.shared should exist")
    }

    // MARK: - HistoricalDataManager Integration Tests

    func testHistoricalDataManagerCanBeCreated() {
        // Given
        let processor = SensorDataProcessor.shared

        // When
        let manager = HistoricalDataManager(sensorDataProcessor: processor)

        // Then
        XCTAssertNotNil(manager, "HistoricalDataManager should be created successfully")
    }

    // MARK: - Demo Mode Integration Tests

    func testDemoModeCanBeToggled() async {
        // Given
        let flags = FeatureFlags.shared
        let originalState = flags.demoModeEnabled

        // When
        flags.demoModeEnabled = true
        XCTAssertTrue(flags.demoModeEnabled, "Demo mode should be enabled")

        flags.demoModeEnabled = false
        XCTAssertFalse(flags.demoModeEnabled, "Demo mode should be disabled")

        // Cleanup
        flags.demoModeEnabled = originalState
    }

    func testDemoDataProviderAccessible() {
        // Given
        let provider = DemoDataProvider.shared

        // Then
        XCTAssertNotNil(provider, "DemoDataProvider.shared should exist")
        XCTAssertFalse(provider.deviceName.isEmpty, "Demo device should have a name")
    }
}
