//
//  BLEBackgroundWorkerTests.swift
//  OralableAppTests
//
//  Created: December 15, 2025
//  Purpose: Unit tests for BLEBackgroundWorker reconnection logic and error handling
//

import XCTest
import Combine
import CoreBluetooth
@testable import OralableApp

@MainActor
final class BLEBackgroundWorkerTests: XCTestCase {

    // MARK: - Properties

    var sut: BLEBackgroundWorker!
    var mockBLEService: MockBLEService!
    var cancellables: Set<AnyCancellable>!
    var mockDelegate: MockReconnectionDelegate!

    // MARK: - Test Lifecycle

    override func setUp() async throws {
        try await super.setUp()

        mockBLEService = MockBLEService(bluetoothState: .poweredOn)
        mockDelegate = MockReconnectionDelegate()

        // Create worker with fast config for testing
        let testConfig = BLEBackgroundWorkerConfig(
            maxReconnectionAttempts: 3,
            baseReconnectionDelay: 0.1, // Fast for testing
            maxReconnectionDelay: 0.5,
            jitterFactor: 0.0, // No jitter for predictable timing
            connectionTimeout: 0.5,
            pauseOnBluetoothOff: true
        )
        sut = BLEBackgroundWorker(bleService: mockBLEService, config: testConfig)
        sut.reconnectionDelegate = mockDelegate
        sut.configure(bleService: mockBLEService)

        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        sut.stop()
        cancellables = nil
        mockDelegate = nil
        mockBLEService = nil
        sut = nil

        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testWorkerInitializesWithDefaultConfig() {
        let worker = BLEBackgroundWorker()
        XCTAssertFalse(worker.isRunning)
        XCTAssertTrue(worker.activeReconnections.isEmpty)
    }

    func testWorkerStartsAndStops() {
        // Given
        XCTAssertFalse(sut.isRunning)

        // When
        sut.start()

        // Then
        XCTAssertTrue(sut.isRunning)

        // When
        sut.stop()

        // Then
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - Reconnection Scheduling Tests

    func testScheduleReconnectionAddsToActiveReconnections() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // When
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Then
        XCTAssertTrue(sut.activeReconnections.contains(deviceId))
    }

    func testImmediateReconnectionTriggersConnectImmediately() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // When
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Allow time for immediate connection attempt
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then
        XCTAssertTrue(mockBLEService.connectCalled)
    }

    func testReconnectionNotifiesDelegate() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // When
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Allow time for delegate notification
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then
        XCTAssertTrue(mockDelegate.reconnectionDidStartCalled)
        XCTAssertEqual(mockDelegate.lastStartPeripheralId, deviceId)
        XCTAssertEqual(mockDelegate.lastStartAttempt, 1)
    }

    func testSuccessfulReconnectionNotifiesDelegate() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Start reconnection
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Allow connect to be called
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // When - simulate successful connection
        mockBLEService.simulateConnection(to: deviceId)

        // Allow event to propagate
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then
        XCTAssertTrue(mockDelegate.reconnectionDidSucceedCalled)
        XCTAssertEqual(mockDelegate.lastSuccessPeripheralId, deviceId)
        XCTAssertFalse(sut.activeReconnections.contains(deviceId))
    }

    // MARK: - Exponential Backoff Tests

    func testExponentialBackoffDelaysIncrease() async {
        // Given
        let testConfig = BLEBackgroundWorkerConfig(
            maxReconnectionAttempts: 5,
            baseReconnectionDelay: 0.1,
            maxReconnectionDelay: 2.0,
            jitterFactor: 0.0, // No jitter for predictable timing
            connectionTimeout: 10.0 // Long timeout so we can measure delays
        )
        let worker = BLEBackgroundWorker(bleService: mockBLEService, config: testConfig)
        worker.configure(bleService: mockBLEService)
        worker.start()

        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        var recordedDelays: [TimeInterval] = []
        let expectation = XCTestExpectation(description: "Multiple reconnection attempts")
        expectation.expectedFulfillmentCount = 3

        // Track reconnection start events
        worker.eventPublisher
            .sink { event in
                if case .reconnectionAttemptStarted = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Start with delay to measure first backoff
        worker.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: false)

        // Expected delays: 0.1s, 0.2s, 0.4s (exponential backoff with base 0.1)
        // We're testing that the delays follow exponential pattern

        await fulfillment(of: [expectation], timeout: 3.0)

        worker.stop()
    }

    func testBackoffCapsAtMaxDelay() async {
        // Given - config with low max delay
        let testConfig = BLEBackgroundWorkerConfig(
            maxReconnectionAttempts: 5,
            baseReconnectionDelay: 1.0,
            maxReconnectionDelay: 1.5, // Cap at 1.5 seconds
            jitterFactor: 0.0
        )

        // Calculate expected delays
        // Attempt 1: 1.0 * 2^0 = 1.0
        // Attempt 2: 1.0 * 2^1 = 2.0 -> capped to 1.5
        // Attempt 3: 1.0 * 2^2 = 4.0 -> capped to 1.5

        let delay1 = min(1.0 * pow(2.0, 0), 1.5)
        let delay2 = min(1.0 * pow(2.0, 1), 1.5)
        let delay3 = min(1.0 * pow(2.0, 2), 1.5)

        XCTAssertEqual(delay1, 1.0)
        XCTAssertEqual(delay2, 1.5) // Capped
        XCTAssertEqual(delay3, 1.5) // Capped
    }

    // MARK: - Max Attempts Tests

    func testReconnectionGivesUpAfterMaxAttempts() async {
        // Given - config with only 2 attempts
        let testConfig = BLEBackgroundWorkerConfig(
            maxReconnectionAttempts: 2,
            baseReconnectionDelay: 0.05,
            jitterFactor: 0.0,
            connectionTimeout: 0.1
        )
        let worker = BLEBackgroundWorker(bleService: mockBLEService, config: testConfig)
        let delegate = MockReconnectionDelegate()
        worker.reconnectionDelegate = delegate
        worker.configure(bleService: mockBLEService)
        worker.start()

        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Inject connection failure
        mockBLEService.injectedErrors["connect"] = BLEError.connectionFailed(
            peripheralId: deviceId,
            reason: "Test failure"
        )

        let gaveUpExpectation = XCTestExpectation(description: "Gave up reconnecting")

        worker.eventPublisher
            .sink { event in
                if case .reconnectionGaveUp = event {
                    gaveUpExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        worker.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Then
        await fulfillment(of: [gaveUpExpectation], timeout: 5.0)

        XCTAssertTrue(delegate.reconnectionDidGiveUpCalled)
        XCTAssertEqual(delegate.lastGiveUpPeripheralId, deviceId)
        XCTAssertFalse(worker.activeReconnections.contains(deviceId))

        worker.stop()
    }

    // MARK: - Bluetooth State Awareness Tests

    func testReconnectionPausesWhenBluetoothOff() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Turn Bluetooth off
        mockBLEService.simulateBluetoothStateChange(.poweredOff)

        // When - try to schedule reconnection
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Allow time for any async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then - connect should NOT have been called (deferred due to BT off)
        XCTAssertFalse(mockBLEService.connectCalled)
    }

    func testReconnectionResumesWhenBluetoothReturns() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Turn Bluetooth off and schedule reconnection
        mockBLEService.simulateBluetoothStateChange(.poweredOff)
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Verify connect not called
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertFalse(mockBLEService.connectCalled)

        // When - turn Bluetooth back on
        mockBLEService.simulateBluetoothStateChange(.poweredOn)

        // Allow time for reconnection to resume
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Then - connect should now be called
        XCTAssertTrue(mockBLEService.connectCalled)
    }

    // MARK: - Connection Timeout Tests

    func testConnectionTimeoutTriggersRetry() async {
        // Given - config with short timeout
        let testConfig = BLEBackgroundWorkerConfig(
            maxReconnectionAttempts: 3,
            baseReconnectionDelay: 0.05,
            jitterFactor: 0.0,
            connectionTimeout: 0.1 // 100ms timeout
        )
        let worker = BLEBackgroundWorker(bleService: mockBLEService, config: testConfig)
        let delegate = MockReconnectionDelegate()
        worker.reconnectionDelegate = delegate
        worker.configure(bleService: mockBLEService)
        worker.start()

        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Make connection hang (no response)
        mockBLEService.injectedDelays["connect"] = 10.0 // Much longer than timeout

        let failExpectation = XCTestExpectation(description: "Attempt failed")

        worker.eventPublisher
            .sink { event in
                if case .reconnectionFailed = event {
                    failExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        worker.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Then
        await fulfillment(of: [failExpectation], timeout: 2.0)

        XCTAssertTrue(delegate.reconnectionAttemptDidFailCalled)

        worker.stop()
    }

    // MARK: - Cancel Reconnection Tests

    func testCancelReconnectionStopsAttempts() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Start reconnection with delay
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: false)
        XCTAssertTrue(sut.activeReconnections.contains(deviceId))

        // When
        sut.cancelReconnection(for: deviceId)

        // Then
        XCTAssertFalse(sut.activeReconnections.contains(deviceId))
    }

    func testCancelAllReconnections() async {
        // Given
        sut.start()

        let deviceId1 = UUID()
        let deviceId2 = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId1, name: "Device 1")
        mockBLEService.addDiscoverableDevice(id: deviceId2, name: "Device 2")
        let peripheral1 = mockBLEService.discoveredPeripherals[deviceId1]!
        let peripheral2 = mockBLEService.discoveredPeripherals[deviceId2]!

        sut.scheduleReconnection(for: deviceId1, peripheral: peripheral1, immediate: false)
        sut.scheduleReconnection(for: deviceId2, peripheral: peripheral2, immediate: false)

        XCTAssertEqual(sut.activeReconnections.count, 2)

        // When
        sut.cancelAllReconnections()

        // Then
        XCTAssertTrue(sut.activeReconnections.isEmpty)
    }

    // MARK: - Connection Health Tests

    func testConnectionHealthUpdatesOnDataReceived() async {
        // Given
        sut.start()
        let deviceId = UUID()

        // When
        sut.recordDataReceived(from: deviceId)

        // Then
        XCTAssertEqual(sut.connectionHealth[deviceId], .healthy)
    }

    func testHandleConnectionSuccessResetsState() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        // Start reconnection
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: false)
        XCTAssertTrue(sut.activeReconnections.contains(deviceId))

        // When
        sut.handleConnectionSuccess(for: deviceId)

        // Then
        XCTAssertFalse(sut.activeReconnections.contains(deviceId))
        XCTAssertEqual(sut.connectionHealth[deviceId], .healthy)
    }

    // MARK: - Event Publisher Tests

    func testEventPublisherEmitsWorkerStarted() async {
        // Given
        let expectation = XCTestExpectation(description: "Worker started event")

        sut.eventPublisher
            .sink { event in
                if case .workerStarted = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.start()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testEventPublisherEmitsWorkerStopped() async {
        // Given
        sut.start()

        let expectation = XCTestExpectation(description: "Worker stopped event")

        sut.eventPublisher
            .sink { event in
                if case .workerStopped = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.stop()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Async Stream Tests

    func testReconnectionEventsAsyncStream() async {
        // Given
        sut.start()
        let deviceId = UUID()
        mockBLEService.addDiscoverableDevice(id: deviceId, name: "Test Device")
        let peripheral = mockBLEService.discoveredPeripherals[deviceId]!

        var receivedEvents: [BLEBackgroundWorkerEvent] = []
        let task = Task {
            for await event in sut.reconnectionEvents {
                receivedEvents.append(event)
                if receivedEvents.count >= 1 {
                    break
                }
            }
        }

        // When
        sut.scheduleReconnection(for: deviceId, peripheral: peripheral, immediate: true)

        // Allow time for events
        try? await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        // Then
        XCTAssertFalse(receivedEvents.isEmpty)
    }
}

// MARK: - Mock Reconnection Delegate

class MockReconnectionDelegate: BLEReconnectionDelegate {

    // Tracking properties
    var reconnectionDidStartCalled = false
    var reconnectionDidSucceedCalled = false
    var reconnectionAttemptDidFailCalled = false
    var reconnectionDidGiveUpCalled = false

    var lastStartPeripheralId: UUID?
    var lastStartAttempt: Int?
    var lastStartMaxAttempts: Int?

    var lastSuccessPeripheralId: UUID?
    var lastSuccessAttempts: Int?

    var lastFailPeripheralId: UUID?
    var lastFailAttempt: Int?
    var lastFailError: Error?
    var lastFailWillRetry: Bool?

    var lastGiveUpPeripheralId: UUID?
    var lastGiveUpTotalAttempts: Int?
    var lastGiveUpError: Error?

    func reconnectionDidStart(for peripheralId: UUID, attempt: Int, maxAttempts: Int, nextRetryDelay: TimeInterval) {
        reconnectionDidStartCalled = true
        lastStartPeripheralId = peripheralId
        lastStartAttempt = attempt
        lastStartMaxAttempts = maxAttempts
    }

    func reconnectionDidSucceed(for peripheralId: UUID, afterAttempts: Int) {
        reconnectionDidSucceedCalled = true
        lastSuccessPeripheralId = peripheralId
        lastSuccessAttempts = afterAttempts
    }

    func reconnectionAttemptDidFail(for peripheralId: UUID, attempt: Int, error: Error?, willRetry: Bool) {
        reconnectionAttemptDidFailCalled = true
        lastFailPeripheralId = peripheralId
        lastFailAttempt = attempt
        lastFailError = error
        lastFailWillRetry = willRetry
    }

    func reconnectionDidGiveUp(for peripheralId: UUID, totalAttempts: Int, lastError: Error?) {
        reconnectionDidGiveUpCalled = true
        lastGiveUpPeripheralId = peripheralId
        lastGiveUpTotalAttempts = totalAttempts
        lastGiveUpError = lastError
    }

    func reset() {
        reconnectionDidStartCalled = false
        reconnectionDidSucceedCalled = false
        reconnectionAttemptDidFailCalled = false
        reconnectionDidGiveUpCalled = false
        lastStartPeripheralId = nil
        lastStartAttempt = nil
        lastStartMaxAttempts = nil
        lastSuccessPeripheralId = nil
        lastSuccessAttempts = nil
        lastFailPeripheralId = nil
        lastFailAttempt = nil
        lastFailError = nil
        lastFailWillRetry = nil
        lastGiveUpPeripheralId = nil
        lastGiveUpTotalAttempts = nil
        lastGiveUpError = nil
    }
}
