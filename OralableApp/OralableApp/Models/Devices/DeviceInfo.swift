//
//  DeviceInfo.swift
//  OralableApp
//
//  Created: November 3, 2025
//  Device information model for multi-device support
//

import Foundation
import CoreBluetooth

/// Complete device information
struct DeviceInfo: Identifiable, Codable, Equatable {
    enum ConnectionStatus: String {
          case disconnected, connecting, connected, disconnecting
      }
    // MARK: - Properties
    
    /// Unique identifier
    let id: UUID
    
    /// Device type
    let type: DeviceType
    
    /// Device name
    let name: String
    
    /// Bluetooth peripheral identifier
    let peripheralIdentifier: UUID?
    
    /// Connection state
    var connectionState: DeviceConnectionState
    
    /// Battery level (0-100)
    var batteryLevel: Int?
    
    /// Signal strength (RSSI)
    var signalStrength: Int?
    
    /// Firmware version
    var firmwareVersion: String?
    
    /// Hardware version
    var hardwareVersion: String?
    
    /// Last connection timestamp
    var lastConnected: Date?
    
    /// Supported sensor types
    let supportedSensors: [SensorType]
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: DeviceType,
        name: String,
        peripheralIdentifier: UUID? = nil,
        connectionState: DeviceConnectionState = .disconnected,
        batteryLevel: Int? = nil,
        signalStrength: Int? = nil,
        firmwareVersion: String? = nil,
        hardwareVersion: String? = nil,
        lastConnected: Date? = nil,
        supportedSensors: [SensorType]? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.peripheralIdentifier = peripheralIdentifier
        self.connectionState = connectionState
        self.batteryLevel = batteryLevel
        self.signalStrength = signalStrength
        self.firmwareVersion = firmwareVersion
        self.hardwareVersion = hardwareVersion
        self.lastConnected = lastConnected
        self.supportedSensors = supportedSensors ?? type.defaultSensors
    }
    
    // MARK: - Computed Properties
    
    /// Display name with connection state
    var statusText: String {
        "\(name) - \(connectionState.displayName)"
    }
    
    /// Battery level text
    var batteryText: String? {
        guard let level = batteryLevel else { return nil }
        return "\(level)%"
    }
    
    /// Signal strength description
    var signalText: String? {
        guard let rssi = signalStrength else { return nil }
        switch rssi {
        case -50...0:
            return "Excellent"
        case -70 ..< -50:
            return "Good"
        case -85 ..< -70:
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    /// Whether device is currently connected
    var isConnected: Bool {
        connectionState == .connected
    }
    
    /// Whether device is connecting
    var isConnecting: Bool {
        connectionState == .connecting
    }
    
    // MARK: - Static Helpers
    
    /// Create a mock device for testing
    static func mock(type: DeviceType = .oralable) -> DeviceInfo {
        DeviceInfo(
            type: type,
            name: type == .oralable ? "Oralable-001" : "ANR-MS-001",
            peripheralIdentifier: UUID(),
            connectionState: .connected,
            batteryLevel: 85,
            signalStrength: -55,
            firmwareVersion: "1.2.3",
            hardwareVersion: "2.0",
            lastConnected: Date()
        )
    }
}

// MARK: - Array Extension

extension Array where Element == DeviceInfo {
    
    /// Get connected devices
    var connected: [DeviceInfo] {
        self.filter { $0.isConnected }
    }
    
    /// Get devices by type
    func devices(ofType type: DeviceType) -> [DeviceInfo] {
        self.filter { $0.type == type }
    }
    
    /// Find device by peripheral identifier
    func device(withPeripheralId peripheralId: UUID) -> DeviceInfo? {
        self.first { $0.peripheralIdentifier == peripheralId }
    }
}
