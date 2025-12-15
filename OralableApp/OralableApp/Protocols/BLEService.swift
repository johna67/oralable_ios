//
//  BLEService.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Protocol abstraction for BLE service operations
//  Enables dependency injection, mocking, and testing
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - BLE Connection State

/// Represents the connection state of a BLE device
enum BLEConnectionState: String, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting..."
        }
    }
}

// MARK: - BLE Service Events

/// Events emitted by the BLE service
enum BLEServiceEvent {
    case deviceDiscovered(peripheral: CBPeripheral, name: String, rssi: Int)
    case deviceConnected(peripheral: CBPeripheral)
    case deviceDisconnected(peripheral: CBPeripheral, error: Error?)
    case bluetoothStateChanged(state: CBManagerState)
    case characteristicUpdated(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data)
    case characteristicWritten(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?)
}

// MARK: - BLE Service Protocol

/// Protocol defining the BLE service interface for scanning, connection, and data operations
/// This abstraction allows for dependency injection and easy mocking in tests
protocol BLEService: AnyObject {

    // MARK: - State

    /// Current Bluetooth state
    var bluetoothState: CBManagerState { get }

    /// Whether Bluetooth is ready for operations
    var isReady: Bool { get }

    /// Whether currently scanning for devices
    var isScanning: Bool { get }

    /// Event publisher for BLE service events
    var eventPublisher: AnyPublisher<BLEServiceEvent, Never> { get }

    // MARK: - Scanning

    /// Start scanning for BLE peripherals
    /// - Parameter services: Optional array of service UUIDs to filter by
    func startScanning(services: [CBUUID]?)

    /// Stop scanning for peripherals
    func stopScanning()

    // MARK: - Connection Management

    /// Connect to a peripheral
    /// - Parameter peripheral: The peripheral to connect to
    func connect(to peripheral: CBPeripheral)

    /// Disconnect from a peripheral
    /// - Parameter peripheral: The peripheral to disconnect from
    func disconnect(from peripheral: CBPeripheral)

    /// Disconnect from all connected peripherals
    func disconnectAll()

    // MARK: - Read/Write Operations

    /// Read value from a characteristic
    /// - Parameters:
    ///   - characteristic: The characteristic to read from
    ///   - peripheral: The peripheral containing the characteristic
    func readValue(from characteristic: CBCharacteristic, on peripheral: CBPeripheral)

    /// Write value to a characteristic
    /// - Parameters:
    ///   - data: The data to write
    ///   - characteristic: The characteristic to write to
    ///   - peripheral: The peripheral containing the characteristic
    ///   - type: The write type (with or without response)
    func writeValue(_ data: Data, to characteristic: CBCharacteristic, on peripheral: CBPeripheral, type: CBCharacteristicWriteType)

    /// Enable/disable notifications for a characteristic
    /// - Parameters:
    ///   - enabled: Whether to enable notifications
    ///   - characteristic: The characteristic to set notifications for
    ///   - peripheral: The peripheral containing the characteristic
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, on peripheral: CBPeripheral)

    // MARK: - Service Discovery

    /// Discover services on a peripheral
    /// - Parameters:
    ///   - services: Optional array of service UUIDs to discover (nil discovers all)
    ///   - peripheral: The peripheral to discover services on
    func discoverServices(_ services: [CBUUID]?, on peripheral: CBPeripheral)

    /// Discover characteristics for a service
    /// - Parameters:
    ///   - characteristics: Optional array of characteristic UUIDs to discover (nil discovers all)
    ///   - service: The service to discover characteristics for
    ///   - peripheral: The peripheral containing the service
    func discoverCharacteristics(_ characteristics: [CBUUID]?, for service: CBService, on peripheral: CBPeripheral)

    // MARK: - Utility

    /// Execute an operation when Bluetooth is ready
    /// - Parameter operation: The operation to execute
    func whenReady(_ operation: @escaping () -> Void)

    /// Retrieve peripherals with the given identifiers
    /// - Parameter identifiers: The peripheral identifiers to retrieve
    /// - Returns: Array of peripherals matching the identifiers
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]
}

// MARK: - Default Implementations

extension BLEService {

    /// Convenience method to start scanning without service filter
    func startScanning() {
        startScanning(services: nil)
    }

    /// Convenience method to write with response
    func writeValue(_ data: Data, to characteristic: CBCharacteristic, on peripheral: CBPeripheral) {
        writeValue(data, to: characteristic, on: peripheral, type: .withResponse)
    }

    /// Convenience method to discover all services
    func discoverServices(on peripheral: CBPeripheral) {
        discoverServices(nil, on: peripheral)
    }

    /// Convenience method to discover all characteristics
    func discoverCharacteristics(for service: CBService, on peripheral: CBPeripheral) {
        discoverCharacteristics(nil, for: service, on: peripheral)
    }
}

// MARK: - BLE Service Error

/// Errors that can occur during BLE service operations
enum BLEServiceError: Error, LocalizedError {
    case bluetoothNotReady
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case peripheralNotConnected
    case serviceNotFound
    case characteristicNotFound
    case writeFailure(Error?)
    case readFailure(Error?)
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothNotReady:
            return "Bluetooth is not ready"
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized"
        case .bluetoothUnsupported:
            return "Bluetooth is not supported on this device"
        case .peripheralNotConnected:
            return "Peripheral is not connected"
        case .serviceNotFound:
            return "Service not found on peripheral"
        case .characteristicNotFound:
            return "Characteristic not found in service"
        case .writeFailure(let error):
            return "Write failed: \(error?.localizedDescription ?? "Unknown error")"
        case .readFailure(let error):
            return "Read failed: \(error?.localizedDescription ?? "Unknown error")"
        case .timeout:
            return "Operation timed out"
        }
    }
}
