//
//  ConnectionStateProvider.swift
//  OralableApp
//
//  Created: Refactoring Phase 3 - Breaking Down God Objects
//  Purpose: Protocol for connection state management, reducing OralableBLE's responsibilities
//

import Foundation
import CoreBluetooth
import Combine

/// Protocol for providing BLE connection state information
/// Extracts connection-related responsibilities from OralableBLE
@MainActor
protocol ConnectionStateProvider: AnyObject {
    // MARK: - Connection State

    /// Whether a device is currently connected
    var isConnected: Bool { get }

    /// Whether the manager is currently scanning for devices
    var isScanning: Bool { get }

    /// Name of the connected device
    var deviceName: String { get }

    /// UUID of the connected device
    var deviceUUID: UUID? { get }

    /// Human-readable connection state
    var connectionState: String { get }

    /// Currently connected peripheral
    var connectedDevice: CBPeripheral? { get }

    // MARK: - Device Discovery

    /// List of discovered peripherals
    var discoveredDevices: [CBPeripheral] { get }

    /// Detailed information about discovered devices
    /// Note: Uses BLEDataPublisher.DiscoveredDeviceInfo type
    var discoveredDevicesInfo: [BLEDataPublisher.DiscoveredDeviceInfo] { get }

    /// Signal strength of connected device (RSSI)
    var rssi: Int { get }

    // MARK: - Publishers for Reactive UI

    var isConnectedPublisher: Published<Bool>.Publisher { get }
    var isScanningPublisher: Published<Bool>.Publisher { get }
    var deviceNamePublisher: Published<String>.Publisher { get }
    var deviceUUIDPublisher: Published<UUID?>.Publisher { get }
    var connectionStatePublisher: Published<String>.Publisher { get }
    var discoveredDevicesPublisher: Published<[CBPeripheral]>.Publisher { get }
    var rssiPublisher: Published<Int>.Publisher { get }

    // MARK: - Connection Management

    /// Start scanning for devices
    func startScanning()

    /// Stop scanning for devices
    func stopScanning()

    /// Connect to a discovered device
    func connect(to peripheral: CBPeripheral)

    /// Disconnect from current device
    func disconnect()
}
