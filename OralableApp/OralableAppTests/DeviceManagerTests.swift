//
//  DeviceManagerTests.swift
//  OralableAppTests
//
//  Created: Phase 2 Refactoring - Test Coverage Expansion
//  Unit tests for DeviceManager functionality
//

import XCTest
import Combine
@testable import OralableApp

@MainActor
final class DeviceManagerTests: XCTestCase {

    var deviceManager: DeviceManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        deviceManager = DeviceManager()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() async throws {
        cancellables = nil
        deviceManager = nil
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(deviceManager, "DeviceManager should initialize")
        XCTAssertNotNil(deviceManager.bleManager, "BLE manager should be initialized")
    }

    func testInitialState() {
        XCTAssertTrue(deviceManager.discoveredDevices.isEmpty, "Should start with no discovered devices")
        XCTAssertTrue(deviceManager.connectedDevices.isEmpty, "Should start with no connected devices")
        XCTAssertNil(deviceManager.primaryDevice, "Should start with no primary device")
        XCTAssertFalse(deviceManager.isScanning, "Should start not scanning")
        XCTAssertFalse(deviceManager.isConnecting, "Should start not connecting")
    }

    // MARK: - Convenience Properties Tests

    func testIsConnectedReflectsConnectedDevices() {
        XCTAssertFalse(deviceManager.isConnected, "Should be false when no devices connected")

        // Add a mock connected device
        let mockDevice = DeviceInfo(
            type: .oralable,
            name: "Test Device",
            connectionState: .connected
        )
        deviceManager.connectedDevices = [mockDevice]

        // Wait a tiny bit for the binding to update
        let expectation = XCTestExpectation(description: "isConnected updates")
        deviceManager.$isConnected
            .dropFirst()
            .sink { isConnected in
                XCTAssertTrue(isConnected, "isConnected should be true when devices are connected")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testDeviceNameReflectsPrimaryDevice() {
        XCTAssertEqual(deviceManager.deviceName, "No Device", "Should default to 'No Device'")

        // Set a primary device
        let mockDevice = DeviceInfo(
            type: .oralable,
            name: "Oralable-123",
            connectionState: .connected
        )

        let expectation = XCTestExpectation(description: "deviceName updates")
        deviceManager.$deviceName
            .dropFirst()
            .sink { name in
                XCTAssertEqual(name, "Oralable-123", "deviceName should reflect primary device name")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        deviceManager.primaryDevice = mockDevice

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - PPG Channel Order Tests

    func testPPGChannelOrderDefaultsToStandard() {
        XCTAssertEqual(deviceManager.ppgChannelOrder, .standard, "Should default to standard")
    }

    func testPPGChannelOrderCanBeChanged() {
        deviceManager.ppgChannelOrder = .alternate

        XCTAssertEqual(deviceManager.ppgChannelOrder, .alternate)
    }

    // MARK: - Sensor Value Updates Tests

    func testSensorValuesUpdateFromLatestReadings() {
        // Initially all zeros
        XCTAssertEqual(deviceManager.heartRate, 0)
        XCTAssertEqual(deviceManager.spO2, 0)
        XCTAssertEqual(deviceManager.temperature, 0.0)

        // Create mock sensor readings
        let hrReading = SensorReading(
            deviceId: UUID(),
            sensorType: .heartRate,
            value: 75.0,
            quality: 0.9,
            timestamp: Date()
        )
        let spo2Reading = SensorReading(
            deviceId: UUID(),
            sensorType: .spo2,
            value: 98.0,
            quality: 0.85,
            timestamp: Date()
        )
        let tempReading = SensorReading(
            deviceId: UUID(),
            sensorType: .temperature,
            value: 36.5,
            quality: nil,
            timestamp: Date()
        )

        let expectation = XCTestExpectation(description: "Sensor values update")
        expectation.expectedFulfillmentCount = 3

        // Subscribe to changes
        deviceManager.$heartRate.dropFirst().sink { hr in
            XCTAssertEqual(hr, 75)
            expectation.fulfill()
        }.store(in: &cancellables)

        deviceManager.$spO2.dropFirst().sink { spo2 in
            XCTAssertEqual(spo2, 98)
            expectation.fulfill()
        }.store(in: &cancellables)

        deviceManager.$temperature.dropFirst().sink { temp in
            XCTAssertEqual(temp, 36.5)
            expectation.fulfill()
        }.store(in: &cancellables)

        // Update latestReadings
        deviceManager.latestReadings = [
            .heartRate: hrReading,
            .spo2: spo2Reading,
            .temperature: tempReading
        ]

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Recording Session Tests

    func testIsRecordingReflectsSessionState() {
        // Initially false
        XCTAssertFalse(deviceManager.isRecording)

        // Note: Full testing of startRecording/stopRecording would require mocking RecordingSessionManager
    }

    // MARK: - Convenience Method Tests

    func testToggleScanningWhenNotScanning() {
        XCTAssertFalse(deviceManager.isScanning)

        // toggleScanning should start scanning (async call)
        deviceManager.toggleScanning()

        // Note: Full test would require async await and proper BLE mocking
    }

    func testClearHistory() {
        // Add some mock data
        let reading = SensorReading(
            deviceId: UUID(),
            sensorType: .heartRate,
            value: 70,
            quality: 0.8,
            timestamp: Date()
        )

        deviceManager.allSensorReadings = [reading]
        deviceManager.latestReadings = [.heartRate: reading]

        XCTAssertFalse(deviceManager.allSensorReadings.isEmpty)
        XCTAssertFalse(deviceManager.latestReadings.isEmpty)

        // Clear history
        deviceManager.clearHistory()

        // Note: clearHistory is async via Task, so we'd need to wait
        // For now, just verify the method exists and can be called
    }

    // MARK: - History Array Tests

    func testBatteryHistoryDerivedFromReadings() {
        let reading1 = SensorReading(deviceId: UUID(), sensorType: .battery, value: 85, quality: nil, timestamp: Date())
        let reading2 = SensorReading(deviceId: UUID(), sensorType: .battery, value: 80, quality: nil, timestamp: Date())

        deviceManager.allSensorReadings = [reading1, reading2]

        let history = deviceManager.batteryHistory

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].percentage, 85)
        XCTAssertEqual(history[1].percentage, 80)
    }

    func testHeartRateHistoryDerivedFromReadings() {
        let reading1 = SensorReading(deviceId: UUID(), sensorType: .heartRate, value: 72, quality: 0.9, timestamp: Date())
        let reading2 = SensorReading(deviceId: UUID(), sensorType: .heartRate, value: 75, quality: 0.85, timestamp: Date())

        deviceManager.allSensorReadings = [reading1, reading2]

        let history = deviceManager.heartRateHistory

        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].bpm, 72)
        XCTAssertEqual(history[1].bpm, 75)
    }

    func testConnectionStatusString() {
        // Not connected, not scanning
        XCTAssertEqual(deviceManager.connectionStatus, "Disconnected")

        // Scanning
        deviceManager.isScanning = true
        XCTAssertEqual(deviceManager.connectionStatus, "Scanning...")

        // Connected
        deviceManager.isScanning = false
        deviceManager.connectedDevices = [DeviceInfo(type: .oralable, name: "Test", connectionState: .connected)]

        let expectation = XCTestExpectation(description: "isConnected updates")
        deviceManager.$isConnected
            .dropFirst()
            .sink { _ in
                XCTAssertEqual(self.deviceManager.connectionStatus, "Connected")
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - RSSI Tests

    func testRSSIFromPrimaryDevice() {
        XCTAssertEqual(deviceManager.rssi, -50, "Should default to -50 when no device")

        let mockDevice = DeviceInfo(
            type: .oralable,
            name: "Test",
            peripheralIdentifier: UUID(),
            connectionState: .connected,
            signalStrength: -65
        )

        deviceManager.primaryDevice = mockDevice

        XCTAssertEqual(deviceManager.rssi, -65, "Should return primary device signal strength")
    }

    // MARK: - Device UUID Tests

    func testDeviceUUID() {
        XCTAssertNil(deviceManager.deviceUUID, "Should be nil when no primary device")

        let uuid = UUID()
        let mockDevice = DeviceInfo(
            id: uuid,
            type: .oralable,
            name: "Test",
            connectionState: .connected
        )

        deviceManager.primaryDevice = mockDevice

        XCTAssertEqual(deviceManager.deviceUUID, uuid, "Should return primary device ID")
    }
}
