//
//  BLEDevice.swift
//  OralableApp
//
//  Created: December 15, 2025
//  Purpose: Simplified BLE device model for protocol-based architecture
//  Contains essential device properties: id, name, battery, connection state
//

import Foundation
import CoreBluetooth

// MARK: - BLE Device Model

/// Simplified BLE device model containing essential device information
/// Used with the BLEService protocol for clean architecture
struct BLEDevice: Identifiable, Equatable, Hashable {

    // MARK: - Core Properties

    /// Unique identifier (matches peripheral identifier)
    let id: UUID

    /// Device name
    var name: String

    /// Battery level (0-100, nil if unknown)
    var batteryLevel: Int?

    /// Current connection state
    var connectionState: BLEConnectionState

    // MARK: - Additional Properties

    /// Signal strength (RSSI in dBm)
    var signalStrength: Int?

    /// Reference to the underlying CBPeripheral (not persisted)
    weak var peripheral: CBPeripheral?

    // MARK: - Initialization

    init(
        id: UUID,
        name: String,
        batteryLevel: Int? = nil,
        connectionState: BLEConnectionState = .disconnected,
        signalStrength: Int? = nil,
        peripheral: CBPeripheral? = nil
    ) {
        self.id = id
        self.name = name
        self.batteryLevel = batteryLevel
        self.connectionState = connectionState
        self.signalStrength = signalStrength
        self.peripheral = peripheral
    }

    /// Initialize from a CBPeripheral
    init(peripheral: CBPeripheral, rssi: Int? = nil) {
        self.id = peripheral.identifier
        self.name = peripheral.name ?? "Unknown Device"
        self.batteryLevel = nil
        self.connectionState = .disconnected
        self.signalStrength = rssi
        self.peripheral = peripheral
    }

    // MARK: - Equatable & Hashable

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Convenience Properties

extension BLEDevice {

    /// Whether the device is currently connected
    var isConnected: Bool {
        connectionState == .connected
    }

    /// Whether the device is in a connecting state
    var isConnecting: Bool {
        connectionState == .connecting
    }

    /// Whether the device is in an active state (connected or connecting)
    var isActive: Bool {
        connectionState == .connected || connectionState == .connecting
    }

    /// Battery level as a percentage string
    var batteryPercentage: String? {
        guard let level = batteryLevel else { return nil }
        return "\(level)%"
    }

    /// Signal quality description based on RSSI
    var signalQuality: String? {
        guard let rssi = signalStrength else { return nil }
        if rssi >= -50 { return "Excellent" }
        if rssi >= -60 { return "Good" }
        if rssi >= -70 { return "Fair" }
        if rssi >= -80 { return "Weak" }
        return "Very Weak"
    }
}

// MARK: - Mutating Methods

extension BLEDevice {

    /// Update the connection state
    mutating func updateConnectionState(_ state: BLEConnectionState) {
        connectionState = state
    }

    /// Update the battery level
    mutating func updateBatteryLevel(_ level: Int) {
        batteryLevel = max(0, min(100, level))
    }

    /// Update the signal strength
    mutating func updateSignalStrength(_ rssi: Int) {
        signalStrength = rssi
    }

    /// Update the device name
    mutating func updateName(_ newName: String) {
        name = newName
    }
}

// MARK: - Collection Extensions

extension Array where Element == BLEDevice {

    /// Filter to only connected devices
    var connected: [BLEDevice] {
        filter { $0.isConnected }
    }

    /// Filter to only disconnected devices
    var disconnected: [BLEDevice] {
        filter { $0.connectionState == .disconnected }
    }

    /// Find device by peripheral identifier
    func device(withId id: UUID) -> BLEDevice? {
        first { $0.id == id }
    }

    /// Find device by peripheral
    func device(for peripheral: CBPeripheral) -> BLEDevice? {
        first { $0.id == peripheral.identifier }
    }

    /// Sort by signal strength (strongest first)
    var sortedBySignal: [BLEDevice] {
        sorted { ($0.signalStrength ?? -100) > ($1.signalStrength ?? -100) }
    }

    /// Sort by name alphabetically
    var sortedByName: [BLEDevice] {
        sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Debug Description

extension BLEDevice: CustomDebugStringConvertible {

    var debugDescription: String {
        var parts: [String] = [
            "BLEDevice(\(name)",
            "id: \(id.uuidString.prefix(8))...",
            "state: \(connectionState.description)"
        ]

        if let battery = batteryLevel {
            parts.append("battery: \(battery)%")
        }

        if let rssi = signalStrength {
            parts.append("rssi: \(rssi) dBm")
        }

        return parts.joined(separator: ", ") + ")"
    }
}
