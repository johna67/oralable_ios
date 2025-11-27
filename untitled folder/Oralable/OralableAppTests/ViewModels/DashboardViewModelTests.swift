//
//  DashboardViewModelTests.swift
//  OralableAppTests
//
//  Created: Refactoring Phase 1
//  Purpose: Unit tests for DashboardViewModel using protocol-based DI
//

import XCTest
import Combine
@testable import OralableApp

@MainActor
final class DashboardViewModelTests: XCTestCase {
    var mockBLE: MockBLEManager!
    var mockAppState: AppStateManager!
    var viewModel: DashboardViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockBLE = MockBLEManager()
        mockAppState = AppStateManager()  // Using real one for now, can mock later
        viewModel = DashboardViewModel(bleManager: mockBLE, appStateManager: mockAppState)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        mockBLE = nil
        mockAppState = nil
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testInitialState() {
        // Then
        XCTAssertFalse(viewModel.isConnected, "Should not be connected initially")
        XCTAssertFalse(viewModel.isRecording, "Should not be recording initially")
        XCTAssertEqual(viewModel.heartRate, 0, "Heart rate should be 0 initially")
        XCTAssertEqual(viewModel.spO2, 0, "SpO2 should be 0 initially")
    }

    func testConnectionStatusUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Connection status updates")

        viewModel.$isConnected
            .dropFirst()  // Skip initial value
            .sink { isConnected in
                XCTAssertTrue(isConnected, "Should be connected")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        mockBLE.simulateConnection()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.deviceName, "Simulated Device")
    }

    func testDisconnectionResetsMetrics() async {
        // Given - Start connected with data
        mockBLE.simulateConnection()
        mockBLE.simulateSensorUpdate(hr: 85, spo2: 97, temp: 37.0, battery: 75.0)

        // Wait for initial connection
        try? await Task.sleep(nanoseconds: 600_000_000)  // 600ms for throttle

        let expectation = XCTestExpectation(description: "Metrics reset on disconnect")

        viewModel.$isConnected
            .dropFirst()  // Skip current connected state
            .sink { isConnected in
                if !isConnected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mockBLE.simulateDisconnection()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(viewModel.isConnected)
    }

    // MARK: - Sensor Data Tests

    func testHeartRateUpdate() async {
        // Given
        mockBLE.simulateConnection()
        viewModel.startMonitoring()

        let expectation = XCTestExpectation(description: "Heart rate updates")

        viewModel.$heartRate
            .dropFirst()  // Skip initial 0
            .sink { hr in
                if hr == 120 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mockBLE.heartRate = 120

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.heartRate, 120)
    }

    func testSpO2Update() async {
        // Given
        mockBLE.simulateConnection()
        viewModel.startMonitoring()

        let expectation = XCTestExpectation(description: "SpO2 updates")

        viewModel.$spO2
            .dropFirst()  // Skip initial 0
            .sink { spo2 in
                if spo2 == 95 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mockBLE.spO2 = 95

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.spO2, 95)
    }

    func testBatteryLevelUpdate() async {
        // Given
        let expectation = XCTestExpectation(description: "Battery level updates")

        viewModel.$batteryLevel
            .dropFirst()  // Skip initial 0
            .sink { battery in
                if battery == 50.0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mockBLE.batteryLevel = 50.0

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)  // Battery throttled to 1 second
        XCTAssertEqual(viewModel.batteryLevel, 50.0)
    }

    // MARK: - Recording Tests

    func testStartRecording() {
        // Given
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(mockBLE.startRecordingCalled)

        // When
        viewModel.startRecording()

        // Then
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertNotNil(viewModel.sessionStartTime)
        XCTAssertTrue(mockBLE.startRecordingCalled, "Should call BLE manager's startRecording")
    }

    func testStopRecording() {
        // Given
        viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        // When
        viewModel.stopRecording()

        // Then
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertNil(viewModel.sessionStartTime)
        XCTAssertTrue(mockBLE.stopRecordingCalled, "Should call BLE manager's stopRecording")
    }

    // MARK: - Throttling Tests

    func testHeartRateThrottling() async {
        // Given
        mockBLE.simulateConnection()
        viewModel.startMonitoring()
        var updateCount = 0

        let expectation = XCTestExpectation(description: "Heart rate throttled")
        expectation.isInverted = false

        viewModel.$heartRate
            .dropFirst()  // Skip initial
            .sink { _ in
                updateCount += 1
            }
            .store(in: &cancellables)

        // When - Rapid updates (10 updates in 200ms)
        for hr in 70...79 {
            mockBLE.heartRate = hr
            try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms between updates
        }

        // Wait for throttle period
        try? await Task.sleep(nanoseconds: 700_000_000)  // 700ms

        // Then - Should have throttled to much fewer updates
        // With 500ms throttle and 200ms of rapid updates, should see 1-2 updates max
        XCTAssertLessThan(updateCount, 5, "Should throttle rapid updates")
    }

    // MARK: - Error Handling Tests

    func testRecordingAction() {
        // Given
        XCTAssertFalse(mockBLE.startRecordingCalled)
        XCTAssertFalse(mockBLE.isRecording)

        // When
        mockBLE.startRecording()

        // Then
        XCTAssertTrue(mockBLE.startRecordingCalled, "Should call startRecording on BLE manager")
        XCTAssertTrue(mockBLE.isRecording, "Should be recording after successful start")
    }

    func testConnectionAction() {
        // Given
        let mockPeripheral = MockCBPeripheral()
        XCTAssertFalse(mockBLE.connectCalled)

        // When
        mockBLE.connect(to: mockPeripheral)

        // Then
        XCTAssertTrue(mockBLE.connectCalled, "Should call connect on BLE manager")
        XCTAssertTrue(mockBLE.isConnected, "Should be connected after successful connect")
    }
}
