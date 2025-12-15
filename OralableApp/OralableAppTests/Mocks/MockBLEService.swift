//
//  MockBLEService.swift
//  OralableAppTests
//
//  Created: December 15, 2025
//  Purpose: Mock BLE service for unit testing DeviceManager and other BLE-dependent classes
//  Allows tests to simulate BLE behavior without actual Bluetooth hardware
//

import Foundation
import Combine
import CoreBluetooth
@testable import OralableApp

/// Mock BLE Service for unit testing
/// Conforms to BLEService protocol and allows simulation of all BLE operations
class MockBLEService: BLEService {

    // MARK: - BLEService Protocol - State

    var bluetoothState: CBManagerState = .poweredOn
    var isReady: Bool { bluetoothState == .poweredOn }
    var isScanning: Bool = false

    /// Event publisher for BLE service events
    var eventPublisher: AnyPublisher<BLEServiceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // MARK: - Internal State for Testing

    private let eventSubject = PassthroughSubject<BLEServiceEvent, Never>()

    /// Simulated discovered peripherals
    var discoveredPeripherals: [UUID: MockPeripheral] = [:]

    /// Simulated connected peripherals
    var connectedPeripherals: Set<UUID> = []

    /// Pending operations queue
    private var pendingOperations: [() -> Void] = []

    // MARK: - Test Tracking Properties

    /// Tracks how many times each method was called
    var methodCallCounts: [String: Int] = [:]

    /// Tracks the parameters passed to methods
    var methodCallParameters: [String: [Any]] = [:]

    /// Errors to inject for testing error handling
    var injectedErrors: [String: Error] = [:]

    /// Delays to inject for testing async behavior (in seconds)
    var injectedDelays: [String: TimeInterval] = [:]

    // MARK: - Convenience Test Flags

    var startScanningCalled: Bool { (methodCallCounts["startScanning"] ?? 0) > 0 }
    var stopScanningCalled: Bool { (methodCallCounts["stopScanning"] ?? 0) > 0 }
    var connectCalled: Bool { (methodCallCounts["connect"] ?? 0) > 0 }
    var disconnectCalled: Bool { (methodCallCounts["disconnect"] ?? 0) > 0 }
    var disconnectAllCalled: Bool { (methodCallCounts["disconnectAll"] ?? 0) > 0 }
    var readValueCalled: Bool { (methodCallCounts["readValue"] ?? 0) > 0 }
    var writeValueCalled: Bool { (methodCallCounts["writeValue"] ?? 0) > 0 }
    var setNotifyValueCalled: Bool { (methodCallCounts["setNotifyValue"] ?? 0) > 0 }

    // MARK: - Initialization

    init(bluetoothState: CBManagerState = .poweredOn) {
        self.bluetoothState = bluetoothState
    }

    // MARK: - BLEService Protocol - Scanning

    func startScanning(services: [CBUUID]?) {
        recordMethodCall("startScanning", parameters: [services as Any])

        guard bluetoothState == .poweredOn else {
            return
        }

        isScanning = true

        // Simulate discovery of pre-configured devices after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulateDiscoveryOfConfiguredDevices()
        }
    }

    func stopScanning() {
        recordMethodCall("stopScanning", parameters: [])
        isScanning = false
    }

    // MARK: - BLEService Protocol - Connection Management

    func connect(to peripheral: CBPeripheral) {
        recordMethodCall("connect", parameters: [peripheral])

        let peripheralId = peripheral.identifier

        // Simulate connection delay
        let delay = injectedDelays["connect"] ?? 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }

            // Check for injected error
            if let error = self.injectedErrors["connect"] {
                self.eventSubject.send(.deviceDisconnected(peripheral: peripheral, error: error))
                return
            }

            self.connectedPeripherals.insert(peripheralId)
            self.eventSubject.send(.deviceConnected(peripheral: peripheral))
        }
    }

    func disconnect(from peripheral: CBPeripheral) {
        recordMethodCall("disconnect", parameters: [peripheral])

        let peripheralId = peripheral.identifier
        connectedPeripherals.remove(peripheralId)

        // Emit disconnection event
        eventSubject.send(.deviceDisconnected(peripheral: peripheral, error: nil))
    }

    func disconnectAll() {
        recordMethodCall("disconnectAll", parameters: [])

        for peripheralId in connectedPeripherals {
            if let mockPeripheral = discoveredPeripherals[peripheralId] {
                eventSubject.send(.deviceDisconnected(peripheral: mockPeripheral, error: nil))
            }
        }
        connectedPeripherals.removeAll()
    }

    // MARK: - BLEService Protocol - Read/Write Operations

    func readValue(from characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        recordMethodCall("readValue", parameters: [characteristic, peripheral])

        // Simulate read completion with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let mockData = Data([0x00, 0x01, 0x02, 0x03])
            self?.eventSubject.send(.characteristicUpdated(
                peripheral: peripheral,
                characteristic: characteristic,
                data: mockData
            ))
        }
    }

    func writeValue(_ data: Data, to characteristic: CBCharacteristic, on peripheral: CBPeripheral, type: CBCharacteristicWriteType) {
        recordMethodCall("writeValue", parameters: [data, characteristic, peripheral, type])

        // Simulate write completion
        if type == .withResponse {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                let error = self?.injectedErrors["writeValue"]
                self?.eventSubject.send(.characteristicWritten(
                    peripheral: peripheral,
                    characteristic: characteristic,
                    error: error
                ))
            }
        }
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        recordMethodCall("setNotifyValue", parameters: [enabled, characteristic, peripheral])
    }

    // MARK: - BLEService Protocol - Service Discovery

    func discoverServices(_ services: [CBUUID]?, on peripheral: CBPeripheral) {
        recordMethodCall("discoverServices", parameters: [services as Any, peripheral])
    }

    func discoverCharacteristics(_ characteristics: [CBUUID]?, for service: CBService, on peripheral: CBPeripheral) {
        recordMethodCall("discoverCharacteristics", parameters: [characteristics as Any, service, peripheral])
    }

    // MARK: - BLEService Protocol - Utility

    func whenReady(_ operation: @escaping () -> Void) {
        recordMethodCall("whenReady", parameters: [])

        if isReady {
            operation()
        } else {
            pendingOperations.append(operation)
        }
    }

    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        recordMethodCall("retrievePeripherals", parameters: [identifiers])

        return identifiers.compactMap { discoveredPeripherals[$0] }
    }

    // MARK: - Test Helper Methods

    /// Record a method call for verification
    private func recordMethodCall(_ method: String, parameters: [Any]) {
        methodCallCounts[method, default: 0] += 1
        methodCallParameters[method, default: []].append(contentsOf: parameters)
    }

    /// Reset all test tracking state
    func reset() {
        methodCallCounts.removeAll()
        methodCallParameters.removeAll()
        injectedErrors.removeAll()
        injectedDelays.removeAll()
        discoveredPeripherals.removeAll()
        connectedPeripherals.removeAll()
        isScanning = false
        bluetoothState = .poweredOn
    }

    /// Simulate Bluetooth state change
    func simulateBluetoothStateChange(_ state: CBManagerState) {
        bluetoothState = state
        eventSubject.send(.bluetoothStateChanged(state: state))

        // Execute pending operations if becoming ready
        if state == .poweredOn {
            let operations = pendingOperations
            pendingOperations.removeAll()
            operations.forEach { $0() }
        }
    }

    /// Add a mock peripheral that will be "discovered" during scanning
    func addDiscoverableDevice(id: UUID, name: String, rssi: Int = -50) {
        let peripheral = MockPeripheral(identifier: id, name: name)
        discoveredPeripherals[id] = peripheral
    }

    /// Simulate device discovery
    func simulateDeviceDiscovery(peripheral: CBPeripheral, name: String, rssi: Int) {
        eventSubject.send(.deviceDiscovered(peripheral: peripheral, name: name, rssi: rssi))
    }

    /// Simulate connection to a specific device
    func simulateConnection(to peripheralId: UUID) {
        guard let peripheral = discoveredPeripherals[peripheralId] else { return }
        connectedPeripherals.insert(peripheralId)
        eventSubject.send(.deviceConnected(peripheral: peripheral))
    }

    /// Simulate disconnection from a specific device
    func simulateDisconnection(from peripheralId: UUID, error: Error? = nil) {
        guard let peripheral = discoveredPeripherals[peripheralId] else { return }
        connectedPeripherals.remove(peripheralId)
        eventSubject.send(.deviceDisconnected(peripheral: peripheral, error: error))
    }

    /// Simulate characteristic update (for testing data reception)
    func simulateCharacteristicUpdate(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {
        eventSubject.send(.characteristicUpdated(peripheral: peripheral, characteristic: characteristic, data: data))
    }

    /// Internal helper to discover pre-configured devices
    private func simulateDiscoveryOfConfiguredDevices() {
        guard isScanning else { return }

        for (_, peripheral) in discoveredPeripherals {
            eventSubject.send(.deviceDiscovered(
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown",
                rssi: -50
            ))
        }
    }
}

// MARK: - Mock Peripheral

/// Mock CBPeripheral subclass for testing
/// Note: CBPeripheral cannot be instantiated directly, so we use a class cluster approach
class MockPeripheral: CBPeripheral {

    private let _identifier: UUID
    private let _name: String?

    init(identifier: UUID, name: String?) {
        self._identifier = identifier
        self._name = name
        // Note: We can't call super.init() as CBPeripheral has no public initializers
        // This is a limitation of mocking CoreBluetooth
    }

    override var identifier: UUID {
        return _identifier
    }

    override var name: String? {
        return _name
    }

    override var state: CBPeripheralState {
        return .disconnected
    }
}

// MARK: - Mock Characteristic

/// Mock CBCharacteristic for testing
class MockCharacteristic: CBCharacteristic {

    private let _uuid: CBUUID
    private let _properties: CBCharacteristicProperties

    init(uuid: CBUUID, properties: CBCharacteristicProperties = [.read, .write, .notify]) {
        self._uuid = uuid
        self._properties = properties
    }

    override var uuid: CBUUID {
        return _uuid
    }

    override var properties: CBCharacteristicProperties {
        return _properties
    }
}

// MARK: - Mock Service

/// Mock CBService for testing
class MockService: CBService {

    private let _uuid: CBUUID
    private let _characteristics: [CBCharacteristic]

    init(uuid: CBUUID, characteristics: [CBCharacteristic] = []) {
        self._uuid = uuid
        self._characteristics = characteristics
    }

    override var uuid: CBUUID {
        return _uuid
    }

    override var characteristics: [CBCharacteristic]? {
        return _characteristics
    }
}
